# Capy na Batatinha — Prévia Multiplayer 1

**Pré-lançamento para testes.** Os pacotes Windows e Android são builds de
depuração existentes, sem recompilação nesta entrega. A validação em Android
real, incluindo controles, áudio e desempenho, ainda está pendente.

## O que jogar

- Singleplayer offline com NPCs, sem servidor ou conexão.
- Multiplayer por IP para até 8 humanos, incluindo o anfitrião.
- 0, 1, 40, 60 ou 80 NPCs adicionais; padrão de 40.
- Rodadas de 75 segundos, com empurrões, quedas e NPCs com máquina de estados.
- Espectador para humanos eliminados ou classificados no multiplayer.

## Downloads e instalação

| Arquivo | Uso |
| --- | --- |
| `CapyMultiplayerWindows.zip` | Windows x64. Extraia tudo e execute `CapyMultiplayer.exe`; mantenha o PCK junto do EXE. |
| `CapyMultiplayerAndroid.apk` | Android arm64. Instale o APK, autorizando a fonte de instalação se o sistema solicitar. |
| `SHA256SUMS.txt` | Hashes SHA-256 dos dois pacotes para conferir a integridade. |

Não é necessário instalar a Godot. O APK usa assinatura de depuração e não é
uma publicação em loja. Os downloads deste repositório privado exigem acesso
ao repositório; o rascunho não é uma distribuição pública.

## Controles

Windows: setas para mover, Shift para correr, Espaço para empurrar e Ctrl
repetidamente para levantar. No Android, use os controles de toque.

## Offline e multiplayer

Para jogar sozinho, escolha **Offline** no menu. Para jogar em grupo, um jogador
escolhe **Hospedar** e os demais usam **Entrar por IP**, com o endereço do
anfitrião e a mesma porta (padrão **7000/UDP**). Todos marcam pronto e o anfitrião
inicia. Todos precisam usar esta mesma versão.

Na mesma rede, use o IP local mostrado na sala. Pela internet, o anfitrião
precisa estar acessível por IP público, com a porta UDP encaminhada se
necessário, ou por uma rede virtual externa compatível com os aparelhos.
CGNAT pode impedir a conexão direta. O GitHub distribui arquivos; não hospeda
as partidas nem fornece relay ou VPN.

## Limitações e testes

- Se o anfitrião sair, a sala termina. Não há migração, reconexão ou entrada
  depois que o carregamento começa.
- Não há matchmaking, contas ou salas por código.
- Ping acima de 200 ms fica fora da meta inicial de qualidade; podem ocorrer
  correções de movimento, sem rebobinamento da física.
- O registro existente documenta 45 verificações de regressão, testes com
  8 processos e 80 NPCs e simulação de latência/perda de pacotes.
- Testes reais Windows–Android, Android como anfitrião, controles, desempenho
  gráfico e conexão pela internet continuam pendentes.

Consulte o [registro de validação](https://github.com/CapyRyanMUs/SquidCapy/blob/66b239e83dc1bba0553c5b877df216bf24db4655/tests/VALIDATION.md)
para distinguir os testes concluídos das pendências.

Para relatar problemas, abra uma [issue](https://github.com/CapyRyanMUs/SquidCapy/issues)
com plataforma, versão, passos para reproduzir e mensagem de erro.

## Referência da entrega

Tag prevista: `multiplayer-preview-1`.
Commit de referência: `66b239e83dc1bba0553c5b877df216bf24db4655`.
As versões internas existentes foram preservadas: projeto `1.0` e Android
`1.5` (código 6). O nome desta prévia identifica os pacotes distribuídos.
