# Desenvolvimento — Capy na Batatinha

Jogo 2D em Godot com capivaras, NPCs com máquina de estados, singleplayer
offline e multiplayer por IP para até **8 humanos**, além de NPCs.

## Abrir e jogar

Use **Godot 4.7.2 stable**, versão confirmada nesta máquina:
`4.7.2.stable.official.ed1daf0bf`. Abra `project.godot` e execute com **F5**.
A entrada é `Cenas/session.tscn`. `Cenas/main_scene.tscn` permanece como
fonte do cenário e das configurações visuais da boneca, não como entrada da sessão.

- **Offline:** escolha aparência e quantidade de NPCs e clique em Offline.
  Não abre conexão ou porta de rede.
- **Hospedar:** escolha uma porta (padrão **7000/UDP**) e clique em Hospedar.
  A sala mostra os IPs locais da máquina.
- **Entrar por IP:** informe o IP do anfitrião e a mesma porta.
- Todos marcam pronto; o anfitrião inicia. A contagem de 3 segundos só começa
  depois de todos carregarem a arena.
- NPCs são adicionais aos humanos: opções 0, 1, 40, 60 ou 80; padrão 40.

Na mesma rede Wi-Fi/LAN, use o IP local do anfitrião. Pela internet, use um
IP público acessível e encaminhe a porta UDP no roteador, se necessário.
Firewall, isolamento entre clientes Wi-Fi e CGNAT podem impedir a conexão.
Não há serviço de relay, descoberta automática, contas ou salas por código.
As duas instalações devem usar a mesma versão do jogo e do protocolo.

## Controles e regras

| Ação | Teclado |
|---|---|
| Mover | Setas |
| Correr | Shift |
| Empurrar | Espaço |
| Levantar após uma queda | Pressionar Ctrl repetidamente |

No Android, as mesmas ações usam os controles de toque. Há risco de tropeçar
ao correr; humanos e NPCs podem empurrar uns aos outros.

A rodada dura 75 segundos. O vermelho possui tolerância de 0,7 segundo.
O anfitrião considera o deslocamento físico efetivo, inclusive empurrões;
tentar andar contra uma parede sem se deslocar não conta como movimento.
Quem foi marcado para eliminação não pode ganhar cruzando a chegada durante
o atraso do disparo.

No offline, a vitória ou morte abre o resultado e permite repetir.
No multiplayer, quem morre ou se classifica assiste aos humanos ainda ativos
e pode alternar a câmera. A rodada acaba quando todos os humanos têm resultado
ou o tempo se esgota; NPCs não prolongam a rodada sozinhos.
O anfitrião retorna todos à sala para outra partida.

Quem desconecta durante a disputa abandona e não é substituído por NPC.
Se o anfitrião sair, todos voltam ao menu. Não há reconexão, migração de
anfitrião ou entrada depois que o carregamento começa.

## Arquitetura e alterações futuras

- `Scripts/session_manager.gd`: sala, ENet, protocolo, carregamento, comandos,
  replicação, resultados e limpeza de sessão.
- `Scripts/LightSys.gd` / `MatchController`: relógio, luzes, arena, spawn,
  avanço da simulação, resultados e câmera de espectador.
- `Scripts/capy_actor.gd`: regras compartilhadas de movimento, empurrão,
  queda, morte e classificação. `filo.gd` e `Bot.gd` adaptam as cenas existentes.
- `States/`: decisões dos NPCs. Transições atribuem o estado antes de
  executar sua entrada; não há corrotinas ou temporizadores de comportamento pendentes.
- `Scripts/session_ui.gd`: menu, sala e resultado.
  `Scripts/UiNode.gd`: HUD e controles do humano local.
- `Cenas/match_config.tres`: recurso editável com parâmetros de partida;
  os padrões estão em `Scripts/match_config.gd`.

O anfitrião executa a simulação a 60 Hz, incluindo IA, sorteios, contatos e
resultados. Clientes enviam direção/corrida a 20 Hz; empurrar e levantar são
ações confiáveis com sequência. Origem, frequência e sequência são validadas.
Comandos de movimento expiram após 250 ms sem atualização.

A admissão usa `SceneMultiplayer.auth_callback` antes de permitir RPCs e
replicação. Clientes recusados nunca recebem personagens da partida em andamento.
Não há retransmissão de RPCs diretamente entre clientes.

`MultiplayerSpawner` cria personagens com IDs estáveis. Snapshots a 20 Hz
usam blocos compactos de até 20 personagens, abaixo do MTU; eventos e o estado
final usam entrega confiável. Identificadores de rodada descartam mensagens antigas.
O movimento local tem previsão e reconciliação, e o remoto é interpolado.
Resultados, colisões, empurrões e sorteios são sempre decididos pelo anfitrião.

O relógio é sincronizado com ping; mudanças de luz são anunciadas 250 ms antes.
O HUD avisa acima de 200 ms. Não há rebobinamento/compensação retroativa de
contatos: conexões de alta latência ainda podem sentir correções.

O modo offline chama a mesma simulação diretamente, usando
`OfflineMultiplayerPeer`, sem servidor externo. Apenas o humano local
instancia controles; a câmera pertence à partida.

## Testes automatizados

Use o executável Godot 4.7.2. Exemplo em PowerShell, a partir da pasta do projeto:

```powershell
$godotExe = 'C:/Users/CapyRyan/Documents/Godot/Godots/Godot_v4.7.2-stable_win64.exe'
& $godotExe --headless --path . --max-fps 60 --log-file './.godot/unit-tests.log' --script res://tests/run.gd
./tests/network_smoke.ps1 -Godot $godotExe -Clients 7 -Npcs 80
python tests/network_conditions.py --godot $godotExe
```

O último comando requer Python 3, sem pacotes adicionais.
O script PowerShell cria processos ocultos e encerra somente os processos
que ele próprio iniciou. Os logs ficam em `.godot/`, fora do versionamento.
Confira a linha `TESTS: ... 0 failures`: algumas versões do executável Windows
sem console não propagam o código de saída como um executável de console.

- `tests/run.gd`: estados, comandos inválidos/repetidos, queda, resultado
  único, spawn, empurrão físico, parede, codec, reinício e timeout de carregamento.
- `tests/network_smoke.ps1`: múltiplos processos, número exato de humanos/NPCs,
  rodada completa e resultados iguais.
- `tests/network_conditions.py`: proxy UDP em loopback com RTT de 50/100/200 ms,
  jitter e 1% de perda; jogadores em movimento; protocolo incompatível,
  saída do anfitrião, entrada tardia, sala cheia e porta ocupada.

Argumentos após `--` usados pelo harness: `--host`, `--join=127.0.0.1`,
`--port=17000`, `--auto-ready`, `--start-after=4`, `--npcs=40`,
`--test-duration=8`, `--test-walk`, `--quit-after=20`, `--report`.
São ferramentas locais de desenvolvimento, não opções recebidas de clientes.

## Exportação Windows e Android

Os presets existentes foram preservados e a permissão Android
`permissions/internet` foi ativada. O projeto continua usando o renderizador
Mobile, resolução-base 576 × 324 e os recursos gráficos/sons existentes.

Foram instalados os componentes Windows x86_64 e Android dos
[templates oficiais 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/),
mantendo os templates 4.4 existentes. SHA-256 do pacote oficial verificado:
`f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.
Em outra máquina, instale os templates dessa mesma versão.

Windows e APK Android de depuração foram exportados com sucesso. O executável
Windows exportado também concluiu uma rodada offline em headless.
O Android usou o SDK/JDK já configurado e build-tools 35.0.1; a engine informou
que não encontrou build-tools com a mesma versão do Target SDK e utilizou
35.0.1, conseguindo alinhar, assinar e verificar o APK. SDK e engine não foram atualizados.

Pacotes de teste: `builds/CapyMultiplayerWindows.zip` (extraia EXE e PCK juntos)
e `builds/CapyMultiplayerAndroid.apk`. São builds de depuração, não uma publicação
em loja. A pasta `builds/` é ignorada pelo Git.
Os caminhos de exportação antigos dos presets ficam fora desta pasta; os
testes usaram caminhos explícitos dentro de `.godot/builds/`.

## Validação em aparelhos e limitações

Veja [o registro de validação](../tests/VALIDATION.md) para resultados e roteiro pendente.
Os testes em processos locais não substituem medir FPS, controles e conforto
do movimento em um Android real e em uma rede Wi-Fi real.

Não foram adicionadas novas fases, alterações de arte, matchmaking, servidor
dedicado ou proteção contra um anfitrião malicioso. O anfitrião é a autoridade
confiável da sala.
