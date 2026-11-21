# Revisão técnica e decisões — Pong Mobile 0.3.5

Base: revisão estática do commit `730300213f195fafcf6d286105ad7040d9b7aa67` (21/11/2026). Neste trabalho o arquivo `scripts/pong.gd` foi lido integralmente, incluindo `_build_interface`, helpers e áudio. Foram executados testes com **Godot 4.7.2 stable**, Linux headless; a experiência física em aparelho Android **não** foi medida.

## Problemas reproduzidos e corrigidos

| Prioridade | Causa e reprodução | Correção | Evidência |
| --- | --- | --- | --- |
| P1 colisão | Raio somado a caixa da raquete aceitava contato falso nos cantos. Bola `(72,329)` e raquete esquerda em `y=270` rebateu sem distância euclidiana suficiente. | Detecção varrida círculo/retângulo, incluindo face e cantos arredondados pelo raio, movimento vertical real da raquete durante o tick e tempo restante após o impacto. Proíbe captura de bola já atrás da face ativa. | `tests/test_p1_regressions.gd`: falhou antes, passou após correção; esquerda/direita, face, tangência, canto, raquete em movimento, escalas 0.7/1.0/1.5. |
| P1 multitouch | Eventos de drag não consultavam `index`; dedo trocava de raquete ao cruzar a metade e terceiros dedos roubavam controle. | Captura única por raquete no press, fixa até release/cancel; drag sem captura ignorado; limpeza em saque, pausa, perda de foco e saída. | `tests/test_p1_regressions.gd`: reprodução por `Input.parse_input_event` com dois dedos e um terceiro, cruzamento, cancelamento e reposição. |
| P1 anúncios | `show_interstitial` aceitava requisição sem bloquear nova partida e `start_match` apagava flag antes do callback de impressão. | Ciclo `IDLE/REQUESTED/SHOWING`, IDs incrementais, callback idempotente por solicitação, bloqueio de navegação durante exibição aceita, timeout de 8s com cancelamento **com garantia**, tratamento de troca do adaptador e callbacks tardios. | `tests/test_ad_lifecycle.gd`: falhou no snapshot; agora cobre atraso, reinício, navegação, duplicados, falha, cancelamento, troca de adaptador e impressão tardia. |
| P2 conclusão duplicada | Pontos e conclusão podiam ser chamados repetidamente após o resultado. | Apenas partidas ativas podem pontuar e cada `match_id` conclui no máximo uma vez. | `CountingPolicy` inspeciona número de chamadas a `note_finished_match`, não apenas contador saturado. |

## Matriz de proporções (simulação headless)

Teste de trajetória horizontal idêntica, dificuldade média, 60 ticks/s e seed fixa. O objetivo é **expor** variação de dimensões e de tempo, não certificar o balanceamento nem equivalência de vitórias.

| Tela simulada | Quadra lógica após `expand` | Primeiro contato com CPU |
| --- | --- | --- |
| 4:3 — 720×540 | 960×720 | 67 ticks (1,117 s) |
| 16:9 — 960×540 | 960×540 | 67 ticks (1,117 s) |
| 20:9 — 1200×540 | 1200×540 | 86 ticks (1,433 s) |

Com a mesma altura de tela, a área lógica pode crescer em **altura** no 4:3 ou em **largura** no 20:9. Mais tempo de trajetória horizontal também causa maior aceleração da bola e altera o tempo de resposta do computador. `tests/test_aspect_matrix.gd` verifica os três cenários. Falta simular milhares de trajetórias variadas, inclusive diagonais, múltiplos rebotes e vitórias, para decidir um rebalanceamento.

## Decisões de jogabilidade adotadas

1. **Toque imediato (P1):** manter controle arcade direto no celular, apesar de ter deslocamento mais rápido que o teclado (`PLAYER_SPEED=640`). Captura por dedo permanece fixa e segura entre eventos.
2. **Quadra `expand` (P2):** manter a tela toda aproveitada; a diferença de tempo entre proporções foi medida e aceita como característica, sem normalização arbitrária neste momento.
3. **Sobrevivência progressiva (P2):** fazer ponto na CPU preserva rebatidas **e velocidade da bola**, inclusive no limite máximo. Uma nova tentativa reinicia a velocidade-base. Regressões em `tests/test_game_rules.gd`.
4. **Sequência competitiva Pro (P2):** abandonar ou reiniciar uma partida **Clássica** ativa, inclusive pausada, zera a sequência corrente; **não** cria derrota nem incrementa partidas. Sair após a vitória mantém a sequência. Testes incluem persistência em disco.

**Decisões adicionais futuras:** se os recordes de Sobrevivência devem separar dificuldades e ajustes Pro; e se as sequências clássicas precisam ser separadas por dificuldade. Não alterado nesta versão.

## Pendências técnicas e validações obrigatórias

- A **Free não tem SDK/IDs AdMob nem anúncios ativos**. O contrato exige que cancelamento do adaptador realmente impeça apresentação futura; se a camada nativa não puder prometer isso, ela deverá informar falha/fechamento antes de destravar o resultado. Integrar consentimento e política de privacidade antes de publicidade real. A **Pro permanece sem SDK**.
- O modelo de varredura interpolou o deslocamento das raquetes realizado **no tick da física**; o toque direto que reposiciona a raquete entre ticks foi **adotado deliberadamente** como regra arcade. Investigar trajetórias diagonais extremas e impacto simultâneo com parede em aparelho.
- Testar multitouch no Android real: duas mãos, cruzamentos, dedo retido sobre botão, corte de app e navegação por gestos. Provar responsividade a 60/90/120 Hz no telefone.
- `expand` foi aprovado, mas resize, IA e recordes de Sobrevivência ainda merecem testes estatísticos. O código atual não foi declarado equilibrado em todos os formatos.
- Gravações síncronas de sliders, recuperação transacional de ConfigFile, isolamento completo de fixtures, perfil de CPU/GPU e suavidade de desenho ainda merecem revisão. **Não houve profiling nem otimização comprovada**.
- Saída `Godot --headless` registra alguns avisos de `ObjectDB instances were leaked at exit` herdados do encerramento da suíte. A suite deve eventualmente liberar todos os recursos; esses avisos não equivalem a vazamento medido no APK.

## Comandos reproduzíveis

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_pong.gd
godot --headless --path . --script res://tests/test_p1_regressions.gd
godot --headless --path . --script res://tests/test_ad_lifecycle.gd
godot --headless --path . --script res://tests/test_aspect_matrix.gd
godot --headless --path . --script res://tests/test_game_rules.gd
```

Também são executados pelos workflows `android.yml` e `google-play.yml`. Builds Android, compatibilidade em aparelho e comportamento de SDK AdMob real são verificações separadas do sucesso desses testes headless.
