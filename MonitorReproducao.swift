//
//  MonitorReproducao.swift
//  Simple-Island
//
//  Created by Felipe Giacomini Cocco on 22/06/26.
//
//  Integração com Spotify e Apple Music (Música.app), e somente eles.
//
//  Estratégia:
//  1) Ouvimos as notificações distribuídas que cada app já posta
//     quando o estado de reprodução muda — é leve e não exige polling.
//  2) Como notificação só chega em MUDANÇA de estado, se o app já
//     estiver tocando algo quando a ilha for iniciada, consultamos o
//     estado atual uma única vez via AppleScript.
//
//  Evitando API privada.
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

    /// Cor de identificação, útil para um indicador na UI da ilha.
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

/// Observa Spotify e Apple Music e expõe a faixa em reprodução, se houver.
///
/// Importante: deve existir UMA única instância, compartilhada entre todas
/// as janelas da ilha (uma por tela). A música tocando é a mesma para o
/// sistema inteiro, diferente de `IslandState`, que é por tela.
final class MonitorDeReproducao: ObservableObject {

    @Published private(set) var faixaAtual: FaixaAtual?

    private let central = DistributedNotificationCenter.default()

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

        DispatchQueue.main.async { [weak self] in
            self?.faixaAtual = faixa
        }
    }

    // MARK: - Consulta inicial via AppleScript

    /// Pergunta diretamente a cada player se algo já está tocando.
    /// Útil só no momento em que a ilha é criada (ou quando um player
    /// pausa e queremos saber se o outro assumiu).
    private func consultarEstadoInicial() {
        for fonte in [FonteMusical.spotify, .appleMusic] {
            guard appEstaAberto(fonte.bundleID) else { continue }
            consultarViaAppleScript(fonte)
        }
    }

    private func appEstaAberto(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func consultarViaAppleScript(_ fonte: FonteMusical) {
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let appleScript = NSAppleScript(source: script) else { return }

            var erro: NSDictionary?
            let descritor = appleScript.executeAndReturnError(&erro)

            if let erro = erro {
                // Código -1743 = o usuário ainda não autorizou este app a
                // controlar o Spotify/Music em Ajustes > Privacidade e
                // Segurança > Automação. Na primeira execução o macOS
                // mostra esse pedido de permissão automaticamente.
                print("MonitorDeReproducao: erro ao consultar \(nomeApp) — \(erro)")
                return
            }

            guard let resultado = descritor.stringValue, !resultado.isEmpty else { return }

            let partes = resultado.components(separatedBy: "||")
            guard partes.count == 3 else { return }

            let faixa = FaixaAtual(titulo: partes[0], artista: partes[1], album: partes[2], fonte: fonte)

            DispatchQueue.main.async {
                self?.faixaAtual = faixa
            }
        }
    }
}
