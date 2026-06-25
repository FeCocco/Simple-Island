//
//  MonitorReproducao.swift
//  Simple-Island
//
//  Integração com Spotify e Apple Music (Música.app), e somente eles.
//

import Foundation
import AppKit
import Combine

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

/// Importante: deve existir UMA única instância, compartilhada entre todas
/// as janelas da ilha (uma por tela). A música tocando é a mesma para o
/// sistema inteiro, diferente de `IslandState`, que é por tela.
///
/// `faixaAtual` e `capaAtual` são publicados separadamente de propósito:
/// a capa chega depois, de forma assíncrona, e não deve disparar de novo
/// as animações de tamanho/bounce que já reagem à troca de faixa.
final class MonitorDeReproducao: ObservableObject {

    @Published private(set) var faixaAtual: FaixaAtual?
    @Published private(set) var capaAtual: NSImage?

    private let central = DistributedNotificationCenter.default()

    /// Toda chamada de AppleScript (consulta de estado OU de capa) passa
    /// por aqui. É serial de propósito: evita várias threads disparando
    /// Apple Events pro mesmo app ao mesmo tempo.
    private let filaAppleScript = DispatchQueue(label: "MonitorDeReproducao.appleScript", qos: .userInitiated)

    /// Identifica a última faixa para a qual já iniciamos uma busca de
    /// capa — usado pra ignorar resultados que chegam atrasados depois
    /// que a faixa já trocou de novo, e pra não rebuscar a mesma capa
    /// em notificações repetidas (Spotify dispara isso até em "seek").
    /// Só é lido/escrito na main thread.
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

        guard estado == "Playing" else {
            // O player pausou ou parou. Só limpamos a ilha se era ESSE
            // player quem estava sendo exibido — e aproveitamos para
            // checar se o outro player passou a tocar.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.faixaAtual?.fonte == fonte {
                    self.faixaAtual = nil
                    self.capaAtual = nil
                    self.chaveDaUltimaCapaBuscada = nil
                    self.consultarEstadoInicial()
                }
            }
            return
        }

        let faixa = FaixaAtual(
            titulo: userInfo["Name"] as? String ?? "",
            artista: userInfo["Artist"] as? String ?? "",
            album: userInfo["Album"] as? String ?? "",
            fonte: fonte
        )

        aplicar(faixa)
    }

    // MARK: - Aplicação de uma nova faixa

    /// Ponto único por onde toda faixa nova passa, venha de notificação
    /// ou de consulta inicial. Decide se vale a pena buscar capa nova.
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

    /// Pergunta diretamente a cada player se algo já está tocando.
    /// Útil só no momento em que a ilha é criada (ou quando um player
    /// pausa e queremos saber se o outro assumiu).
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
            if player state is playing then
                return (name of current track) & "||" & (artist of current track) & "||" & (album of current track)
            else
                return ""
            end if
        end tell
        """

        filaAppleScript.async { [weak self] in
            guard let self = self,
                  let resultado = self.executarAppleScript(script)?.stringValue,
                  !resultado.isEmpty else { return }

            let partes = resultado.components(separatedBy: "||")
            guard partes.count == 3 else { return }

            let faixa = FaixaAtual(titulo: partes[0], artista: partes[1], album: partes[2], fonte: fonte)
            self.aplicar(faixa)
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
            if let erro = erro {
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
