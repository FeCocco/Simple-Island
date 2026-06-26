//
//  MonitorReproducao.swift
//  Simple-Island
//
//  Integração com Spotify e Apple Music (Música.app), e somente eles.
//

import Foundation
import AppKit
import Combine
import SwiftUI

enum FonteMusical: Equatable {
    case spotify
    case appleMusic

    var nomeExibicao: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }

    var bundleID: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        }
    }

    var nomeParaAppleScript: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Music"
        }
    }

    /// Cor de identificação, usada no indicador/placeholder da ilha.
    var cor: NSColor {
        switch self {
        case .spotify: return NSColor(red: 0.11, green: 0.84, blue: 0.38, alpha: 1)   // verde Spotify
        case .appleMusic: return NSColor(red: 0.98, green: 0.16, blue: 0.35, alpha: 1) // rosa/vermelho Apple Music
        }
    }
}

struct FaixaAtual: Equatable {
    var titulo: String
    var artista: String
    var album: String
    var fonte: FonteMusical
}

final class MonitorDeReproducao: ObservableObject {

    @Published private(set) var faixaAtual: FaixaAtual?
    @Published private(set) var capaAtual: NSImage?
    @Published private(set) var estaTocando: Bool = false

    private let central = DistributedNotificationCenter.default()

    private let filaAppleScript = DispatchQueue(label: "MonitorDeReproducao.appleScript", qos: .userInitiated)

    private var chaveDaUltimaCapaBuscada: String?

    init() {
        observarNotificacoes()
        consultarEstadoInicial()
    }

    deinit {
        central.removeObserver(self)
    }

    // MARK: - Notificações distribuídas

    private func observarNotificacoes() {
        central.addObserver(
            self,
            selector: #selector(spotifyMudou(_:)),
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        central.addObserver(
            self,
            selector: #selector(appleMusicMudou(_:)),
            name: Notification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
    }

    @objc private func spotifyMudou(_ notificacao: Notification) {
        processar(userInfo: notificacao.userInfo, fonte: .spotify)
    }

    @objc private func appleMusicMudou(_ notificacao: Notification) {
        processar(userInfo: notificacao.userInfo, fonte: .appleMusic)
    }

    private func processar(userInfo: [AnyHashable: Any]?, fonte: FonteMusical) {
        guard let userInfo = userInfo else { return }

        let estado = userInfo["Player State"] as? String
        let estaTocandoAgora = (estado == "Playing")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.estaTocando = estaTocandoAgora
            
            if !estaTocandoAgora {
                Task {
                    try? await Task.sleep(for: .seconds(10)) //MARK: Talvez seja bom deixar o usuario final esqcolher esse tempo
                    
                    if !self.estaTocando && self.faixaAtual?.fonte == fonte {
                        withAnimation {
                            self.faixaAtual = nil
                            self.capaAtual = nil
                            self.chaveDaUltimaCapaBuscada = nil
                        }
                    }
                }
            } else {
                let faixa = FaixaAtual(
                    titulo: userInfo["Name"] as? String ?? "",
                    artista: userInfo["Artist"] as? String ?? "",
                    album: userInfo["Album"] as? String ?? "",
                    fonte: fonte
                )
                self.aplicar(faixa)
            }
        }
    }

    // MARK: - Aplicação de uma nova faixa

    private func aplicar(_ faixa: FaixaAtual) {
        let chave = chaveDaFaixa(faixa)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let mesmaFaixaDeJa = self.faixaAtual == faixa

            self.faixaAtual = faixa

            guard !mesmaFaixaDeJa else { return }

            // Some com a capa antiga imediatamente — evita mostrar a capa
            // da música anterior por um instante enquanto a nova carrega.
            self.capaAtual = nil
            self.chaveDaUltimaCapaBuscada = chave
            self.buscarCapa(para: faixa, chaveEsperada: chave)
        }
    }

    private func chaveDaFaixa(_ faixa: FaixaAtual) -> String {
        "\(faixa.fonte.bundleID)|\(faixa.titulo)|\(faixa.artista)|\(faixa.album)"
    }

    // MARK: - Consulta inicial via AppleScript (faixa já tocando)

    private func consultarEstadoInicial() {
        for fonte in [FonteMusical.spotify, .appleMusic] {
            guard appEstaAberto(fonte.bundleID) else { continue }
            consultarFaixaAtual(fonte)
        }
    }

    private func appEstaAberto(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func consultarFaixaAtual(_ fonte: FonteMusical) {
        let nomeApp = fonte.nomeParaAppleScript

        
        let script = """
        tell application "\(nomeApp)"
            return (name of current track) & "||" & (artist of current track) & "||" & (album of current track) & "||" & (player state as text)
        end tell
        """

        filaAppleScript.async { [weak self] in
            guard let self = self,
                  let resultado = self.executarAppleScript(script)?.stringValue,
                  !resultado.isEmpty else { return }
            
            let componentes = resultado.components(separatedBy: "||")
            
            if componentes.count >= 4 {
                let nome = componentes[0]
                let artista = componentes[1]
                let album = componentes[2]
                
                let estadoTexto = componentes[3].trimmingCharacters(in: .whitespacesAndNewlines)
                
                let tocando = (estadoTexto == "playing")
                
                let faixa = FaixaAtual(titulo: nome, artista: artista, album: album, fonte: fonte)
                
                DispatchQueue.main.async {
                    self.aplicar(faixa)
                    self.estaTocando = tocando
                }
            }
        }
    }
    

    // MARK: - Capa do álbum

    private func buscarCapa(para faixa: FaixaAtual, chaveEsperada: String, tentativa: Int = 0) {
        filaAppleScript.async { [weak self] in
            guard let self = self else { return }

            switch faixa.fonte {
            case .spotify:
                self.capaDoSpotify { imagem in
                    self.receberCapaBuscada(imagem, faixa: faixa, chaveEsperada: chaveEsperada, tentativa: tentativa)
                }
            case .appleMusic:
                let imagem = self.capaDoAppleMusic()
                self.receberCapaBuscada(imagem, faixa: faixa, chaveEsperada: chaveEsperada, tentativa: tentativa)
            }
        }
    }

    private func receberCapaBuscada(_ imagem: NSImage?, faixa: FaixaAtual, chaveEsperada: String, tentativa: Int) {
        if let imagem = imagem {
            let miniatura = redimensionar(imagem, para: NSSize(width: 80, height: 80))

            DispatchQueue.main.async { [weak self] in
                guard let self = self, chaveEsperada == self.chaveDaUltimaCapaBuscada else {
                    return
                }
                self.capaAtual = miniatura
            }
        } else if faixa.fonte == .appleMusic && tentativa < 1 {
            filaAppleScript.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.buscarCapa(para: faixa, chaveEsperada: chaveEsperada, tentativa: tentativa + 1)
            }
        }
    }

    private func capaDoSpotify(completion: @escaping (NSImage?) -> Void) {
        let script = """
        tell application "Spotify"
            if player state is playing then
                return artwork url of current track
            else
                return ""
            end if
        end tell
        """

        guard var urlString = executarAppleScript(script)?.stringValue,
              !urlString.isEmpty else {
            completion(nil)
            return
        }

        // CORREÇÃO ATS: O Spotify devolve "http://", mas o macOS exige "https://"
        if urlString.hasPrefix("http://") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { dados, _, erro in
            if erro != nil {
                completion(nil)
                return
            }

            guard let dados = dados, let imagem = NSImage(data: dados) else {
                completion(nil)
                return
            }

            completion(imagem)
        }.resume()
    }

    private func capaDoAppleMusic() -> NSImage? {
        let script = """
        tell application "Music"
            if player state is playing then
                return data of artwork 1 of current track
            else
                return ""
            end if
        end tell
        """

        guard let descritor = executarAppleScript(script) else {
            return nil
        }
        
        let dados = descritor.data
        guard !dados.isEmpty else {
            return nil
        }

        if let imagem = NSImage(data: dados) {
            return imagem
        } else {
            return nil
        }
    }

    private func redimensionar(_ imagem: NSImage, para tamanho: NSSize) -> NSImage {
        let miniatura = NSImage(size: tamanho)
        miniatura.lockFocus()
        imagem.draw(
            in: NSRect(origin: .zero, size: tamanho),
            from: NSRect(origin: .zero, size: imagem.size),
            operation: .copy,
            fraction: 1.0
        )
        miniatura.unlockFocus()
        return miniatura
    }
    
    
    //MARK: Controles de mídia
    
    func enviarComando(_ comando: String, para fonte: FonteMusical) {
            let nomeApp = fonte.nomeParaAppleScript
            
            let script = """
            tell application "\(nomeApp)"
                \(comando)
            end tell
            """
            
            filaAppleScript.async { [weak self] in
                _ = self?.executarAppleScript(script)
            }
        }

    // MARK: - AppleScript

    private func executarAppleScript(_ script: String) -> NSAppleEventDescriptor? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var erro: NSDictionary?
        let descritor = appleScript.executeAndReturnError(&erro)

        if let erro = erro {
            print("MonitorDeReproducao: erro no AppleScript — \(erro)")
            return nil
        }

        return descritor
    }
}
