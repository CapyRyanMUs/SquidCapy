# Registro de validação

Ambiente: Windows, Godot 4.7.2 stable oficial, protocolo de aplicação 1.
Os cenários automatizados usam execução headless; não são medições gráficas.

## Resultados obtidos

- Rodada offline com 40 NPCs: iniciou e terminou.
- 45 verificações de regressão: passaram.
- Host e cliente separados, 40 NPCs: resultados idênticos.
- 8 humanos (8 processos), 80 NPCs: resultados idênticos e saída dos clientes sem referências inválidas.
- RTT 50, 100 e 200 ms, jitter e perda UDP de 1%, com humanos em movimento:
  clientes receberam snapshots e apresentaram os mesmos resultados do host.
- Protocolo incompatível: rejeição com mensagem.
- Saída do anfitrião: cliente retorna ao menu.
- Entrada após início: rejeição com mensagem.
- Sala com 8 humanos: conexão adicional rejeitada como sala cheia.
- Segunda hospedagem na mesma porta: erro de porta ocupada.
- Menu principal: tamanho mínimo cabe na largura-base de 576 pixels.
- Templates oficiais 4.7.2 para Windows x64 e Android instalados após verificação SHA-256.
- Exportação Windows de depuração e rodada offline no executável exportado: concluídas.
- APK arm64 de depuração: exportado, alinhado, assinado e verificado pelas ferramentas Android.

O harness é reproduzível pelos comandos do README. Os relatórios detalhados
ficam em `.godot/unit-tests.log`, `.godot/network-tests/` e
`.godot/network-conditions/`; não são arquivos necessários para distribuir o jogo.

O ambiente restrito apresentou aviso da engine ao ler o repositório de
certificados do Windows. O jogo usa UDP/ENet, sem HTTPS. A importação no editor
também não conseguiu salvar preferências globais fora da pasta autorizada;
isso não é uma falha de compilação dos scripts.

## Pendências externas

- Nenhum dispositivo encontrado por `adb devices`.
- Validação visual, áudio, multitouch, suspensão/retomada e desempenho gráfico
  em Windows/Android reais ainda pendentes.
- Partida por IP público real, firewall e roteador não exercitados.
- `git diff --check` não pôde comparar a revisão: Git informou objeto
  `ab6981af17db5c2594b7ef27b7fc83f2cc3b41f6` indisponível. O histórico
  não foi reconstruído nem resetado; os arquivos e testes funcionam independentemente disso.

## Roteiro Windows–Android

1. Exportar as duas plataformas com a mesma engine, templates e revisão.
2. Com o celular sem Wi-Fi/dados, jogar offline, correr, cair, levantar,
   empurrar, vencer/morrer e repetir cinco vezes.
3. Na mesma rede, hospedar no Windows e entrar pelo Android; depois inverter.
4. Confirmar que cada aparelho só controla sua capivara, com sua própria câmera.
5. Testar toque simultâneo: mover + correr e mover + empurrar; soltar todos
   os botões após abrir/fechar a tela de resultado.
6. Empurrar humanos e NPCs em ambas as direções e perto de paredes.
   Confirmar o mesmo alvo caído nos dois aparelhos.
7. Morrer enquanto está caído ou empurrando; tentar cruzar a chegada depois
   de ser marcado para eliminação. Conferir que existe apenas um resultado.
8. Classificar um humano enquanto outro continua; alternar espectador,
   confirmar que classificado não bloqueia/empurra participantes ativos.
9. Retornar à sala e iniciar três rodadas seguidas com quantidades diferentes de NPCs.
10. Desconectar cliente durante a disputa e fechar o aplicativo anfitrião.
    Conferir abandono, resultado coletivo e retorno ao menu.
11. Bloquear a tela/colocar o anfitrião Android em segundo plano; conferir
    aviso/desconexão nos demais. A primeira versão não oferece hospedagem em
    serviço Android de segundo plano.
12. Repetir com 0, 40 e 80 NPCs e até 8 humanos. Registrar aparelho, sistema,
    papel host/cliente, média/mínimo de FPS, tempo de física e ping.

| Aparelho / SO | Host ou cliente | Humanos / NPCs | FPS médio / mínimo | Física (ms) | Ping (ms) |
|---|---|---|---|---|---|
| Pendente: nenhum Android conectado | — | — | — | — | — |

Critérios: nenhum erro de script ou resultado divergente; controles legíveis
e utilizáveis; sem câmera/HUD duplicados; sem crescimento de nós/sons entre
rodadas. Desempenho aceitável deve ser confirmado no aparelho-alvo antes da publicação.
