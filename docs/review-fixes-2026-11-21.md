# Correções para a próxima revisão — Pong Mobile

Base de trabalho: commit `3e8fd71c43043d567d6ca86043b637c7c70ccc19` (0.3.5).
Objetivo: entregar código e regressões para outra rodada de *code review*, **sem APK, AAB, SDK ou IDs de anúncios de produção**. O código não recebe novo número de release nesta rodada.

## Achados e mudanças

| ID | Causa e reprodução antes | Correção / funções alteradas | Regressão | Status local |
| --- | --- | --- | --- | --- |
| FIS-01 | Parede truncava o deslocamento além do limite, por exemplo `29 → 24` terminava em `28`, não `32`. | `scripts/pong.gd::_advance_ball_substep`: calcula o primeiro tempo de impacto e continua pelo tempo restante. | `test_collision_timing.gd`: superior, inferior, diagonal, módulo e um passo vs. meios passos. | Corrigido nos testes headless. |
| FIS-02 | A varredura de raquete era aplicada antes da parede, mesmo quando a parede ocorria primeiro. | `_advance_ball_substep`: compara candidatos de parede, raquete e gol, processa o menor tempo, limita a 12 contatos/subpasso e emite diagnóstico se o limite for excedido. Empates de parede/raquete resolvem a parede primeiro. | `test_collision_timing.gd`: parede→raquete, raquete→parede, simetria e escalas 0,7/1/1,5, em alta velocidade. | Corrigido nos testes headless. |
| INPUT-01 | `_reset_round` apagava os IDs dos dedos e recentralizava as raquetes após cada ponto. | `_reset_ball_for_serve` reinicia apenas bola, alvo e rastro; capturas e posições permanecem entre saques. Novas partidas, pausa, perda de foco, cancelamento e saída continuam liberando. | `test_p1_regressions.gd`: dois dedos atravessando o centro e mantidos após ponto, terceiro dedo ignorado. | Corrigido nos testes headless. |
| INPUT-02 | O toque imediato podia posicionar uma raquete já sobre a bola, após o ponto de contato nominal. | `_sweep_paddle_contact` aceita sobreposição **somente à frente da face, com bola aproximando**; `_separate_from_paddle_front` resolve a sobreposição antes do único rebote. A trajetória inteira do teleporte não é tratada como varredura. | `test_p1_regressions.gd`: toque/drag real frontal, canto, não duplicação e rejeição atrás da face. | Regra implementada e testada headless. |
| ADS-01 | Um único `cancel_interstitial=false` mantinha a solicitação bloqueada indefinidamente sem nova tentativa; `SHOWING` não tinha recuperação. | `_process`, `_notification`, `_update_ad_status`: cancelamentos repetidos (4 s), recuperação nativa após timeout de 8 s em `REQUESTED` ou 120 s em `SHOWING`, reconciliação ao retomar app e botão **Fechar jogo** como saída segura. O adaptador passa a exigir `recover_interstitial(id) -> bool` com garantia terminal nativa. | `test_ad_lifecycle.gd`: callback ausente, cancelamento false, nova tentativa, retomada, exibição sem fechamento e callback tardio após recuperação. | Simulação aprovada. **Integração AdMob real continua bloqueada até haver adaptador nativo comprovado.** |
| STAT-01 | Sem marcador de partida ativa salvo, matar o processo mantinha a sequência anterior. | `_start_match` salva `active_classic_match`; `_record_pro_stats` e `_break_streak_on_abandon` limpam; `_load_pro_stats` zera apenas a sequência corrente se recuperar marcador pendente. Pausa não limpa. | `test_game_rules.gd`: marcador ativo, conclusão limpa, pausa preserva, nova instância detecta abandono, sem derrota falsa. | Corrigido nos testes headless; verificar crash/process kill em Android. |
| UI-01 | Durante countdown, `ball_velocity=ZERO` fazia o HUD mostrar `BOLA 1,0x` mesmo com saque acelerado. | `_displayed_ball_speed_ratio` usa `_serve_speed` no countdown e exibe **PRÓXIMA BOLA**. | `test_game_rules.gd`: HUD e transição real pelo `_physics_process`. | Corrigido no modelo e na lógica exibida. |
| TEST-01 | Um teste antigo exigia indevidamente perder captura após ponto; outras regras não percorriam o fluxo integrado. | Teste invertido para continuidade; nova suíte de colisão; sobrevivência pelo gol e countdown reais; testes de persistência e recuperação assíncrona. Workflows incluem a nova suíte, mas **não serão disparados nesta branch**. | Seis suítes headless. | Ampliado; aparelhos físicos pendentes. |
| PERF-01 | Suspeitas de redesenho integral e renderização a altas taxas, sem profiler. | Nenhuma mudança de desempenho deliberada. | Medição p50/p95/p99, 60/90/120 Hz, multitouch e sessão prolongada ainda necessária. | Pendente, sem alegação de melhora de FPS. |
| REG-FIS-01 | Após a correção anterior, o candidato de contato na face superior/inferior aceitava `front_sign * x >= half_width`, **sem limite máximo horizontal**; gerava falsos rebotes distantes e rejeitava contato verdadeiro no segmento plano. | `_sweep_paddle_contact`: restringir a metade plana frontal ao intervalo `0 <= front_sign * x <= half_width + 0.0001`. Os cantos permanecem sob o teste euclidiano. | `test_sweep_geometry.gd`: quatro contraexemplos simétricos, contatos positivos nas escalas 0,7/1/1,5, 4.050 trajetórias; oráculos independentes para **contatos falsos e perdidos**, superfície de contato e integração com solver. | Corrigido em Godot headless; não validado em Android. |
| DATA-01 | Configurações e estatísticas Pro eram gravadas diretamente no arquivo principal; corrupção podia apagar personalização, recordes e sequência. | `_save_config_with_backup` grava em `.tmp`, preserva um `.bak` do arquivo principal válido e só depois substitui o principal; `_load_config_with_backup` recupera o backup após falha de leitura. Nunca usa um arquivo principal corrompido como backup. | `test_storage_recovery.gd`: simula corrupção dos dois arquivos, recria a cena, verifica restauração de personalização e histórico, tratamento da partida ativa, manutenção do backup válido e ausência de temporários. | Corrigido nos testes headless; não há garantia de `fsync`/durabilidade contra corte de energia. |
| STORE-01 | A Free divulgava um botão Pro que poderia apontar para ficha ainda indisponível. | `_build_interface`: botão Pro só visível no Android com feature `pong_pro_store_live`; texto da loja ajustado à publicação futura. | `test_pong.gd`: Free não anuncia a Pro enquanto a feature não for habilitada. | Corrigido; habilitar tag somente depois de publicar a ficha Pro. |
| BUILD-01 | Projeto declarava Godot 4.4 enquanto workflows usam 4.7.2. | `project.godot`: `config/features` passa para `4.7`; workflows executam a oitava suíte de recuperação. | `test_pong.gd`: verifica a versão declarada; importação do editor e oito suítes headless locais. | Validado localmente; CI remoto depende do PR. |

## Evidência de execução

Plataforma usada: Linux, Godot `4.7.2.stable.official.ed1daf0bf`, modo headless.

Regressões adicionadas **antes** da correção reproduziram 6 falhas de física, 2 de continuidade de toque, 6 de anúncios e 3 de regras/HUD. Após as alterações, foram executados:

```bash
godot --headless --path . --script res://tests/test_pong.gd
godot --headless --path . --script res://tests/test_p1_regressions.gd
godot --headless --path . --script res://tests/test_ad_lifecycle.gd
godot --headless --path . --script res://tests/test_aspect_matrix.gd
godot --headless --path . --script res://tests/test_game_rules.gd
godot --headless --path . --script res://tests/test_collision_timing.gd
godot --headless --path . --script res://tests/test_sweep_geometry.gd
godot --headless --path . --script res://tests/test_storage_recovery.gd
```

As seis suítes originais retornaram código `0`. Posteriormente, na correção **REG-FIS-01**, o teste geométrico novo apresentou sete asserções falhas antes do ajuste e passou depois dele. O resultado final abrange **sete suítes**. Alguns testes ainda geram avisos `ObjectDB instances were leaked at exit` no encerramento do harness; **não** representam prova de vazamento no Android.

### Reforço da evidência geométrica solicitado na revisão

O oráculo foi ampliado sem alterar a lógica de física. Em uma grade de **4.050 trajetórias determinísticas** (1.350 por escala), verifica para cada contato declarado a distância euclidiana ao retângulo desenhado: `abs(distância - raio) <= 0,05`. A grade começa **sem sobreposição**, pois contatos iniciais do toque arcade podem legitimamente ter distância menor que o raio.

Um segundo oráculo amostra 160 subdivisões do segmento e exige contato para aproximações que penetram mais de 0,65 pixel no círculo-retângulo, considerando somente a metade frontal da raquete. Na execução local, identificou 344 contatos necessários em 0,7×, 360 em 1,0× e 368 em 1,5×, todos detectados; também não houve contato declarado fora da superfície. O nome local `sign` foi substituído por `front_sign` e as mensagens agora diferenciam contatos inválidos de colisões perdidas.

**Regra de produto mantida:** impactos na metade traseira da face superior/inferior não são defensáveis quando a bola já cruzou a face ativa. É uma convenção arcade anterior a REG-FIS-01, não uma aproximação geométrica escondida. A suíte cobre essa rejeição simetricamente; a amostragem não deve exigir contato após a bola entrar na região traseira.

## Políticas deliberadas e limites da entrega

- **Toque imediato** e `stretch/aspect=expand` permanecem. A raquete pode saltar instantaneamente para o ponto do dedo, mas não resgata bola que já passou da face.
- Encerrar o processo em meio a uma partida Clássica é tratado como **abandono ao reabrir**: perde somente a sequência corrente; não incrementa derrotas, não penaliza pausa temporária e preserva o melhor recorde.
- Não há integração nativa nem ID de produção para anúncios. O adaptador deve provar a segurança de `recover_interstitial`, sem simplesmente ignorar callbacks tardios. Se a camada nativa não puder liberar com segurança, o jogo permanece no resultado com opção de sair do aplicativo.
- Arquivos de estatísticas ainda usam `ConfigFile.save` diretamente, sem transação/backup atômico. Erros de gravação produzem aviso; tolerância a corrupção/corte de energia e garantias de durabilidade continuam para outra revisão.
- Preferências e estatísticas Pro agora usam gravação em temporário, backup válido e recuperação após corrupção do arquivo principal. **Isso não garante durabilidade transacional em quedas de energia:** não foi comprovada sincronização em armazenamento físico nem tolerância a interrupção durante a substituição do arquivo.
- Nenhum APK/AAB foi gerado; não houve teste em Android físico, medição de FPS, teste de interrupção por sistema operacional ou integração com rede de anúncios.
- Este material é **candidato à revisão**, não sinal verde para a Google Play.

## Complemento para PR de revisão (21/11/2026)

A documentação acima descreve a primeira rodada da branch; nesta rodada, além do ajuste REG-FIS-01, foram tratados **DATA-01, STORE-01 e BUILD-01**. A afirmação anterior de que os workflows *não seriam disparados* e de que não haveria *APK gerado* referia-se apenas à entrega local: **abrir um pull request dispara o workflow `android.yml`, que também exporta APKs de teste como artefatos de CI.** Não foi solicitado AAB de publicação nem integração de anúncios reais.

Comandos executados no Linux (Godot `4.7.2.stable.official.ed1daf0bf`): as **oito suítes listadas acima** retornaram **código de saída 0**, assim como `godot --headless --path . --editor --import --quit`. `test_storage_recovery.gd` imprime erros esperados do parser de `ConfigFile` porque os arquivos são corrompidos deliberadamente; as asserções de recuperação passaram. O resultado final da execução no GitHub Actions deve ser registrado após o disparo do PR. Não houve execução Android física nem profiler.

## Política de distribuição após o merge do PR #1

O primeiro PR foi integrado com os workflows aprovados, mas seus APKs Free/Pro foram anexados a execuções **públicas** do Actions. Por solicitação posterior, os três workflows foram ajustados para **somente compilar/verificar** APKs, AABs e imagens nos runners: não há mais `actions/upload-artifact` nem acesso ao keystore real de publicação na execução pública. O modo `release` do AAB foi retirado; a assinatura final deve ser feita localmente, conforme o README.

O teste em `android.yml` impede a reintrodução acidental de uploads públicos e dos segredos `PLAY_UPLOAD_*`. As oito suítes Godot e a análise sintática dos três YAMLs passaram localmente após essa mudança. Isso não oculta o código, as imagens já versionadas ou os logs públicos do Actions. **Artefatos antigos continuam acessíveis até serem removidos no GitHub**; excluir o código dos workflows não os apaga retroativamente.
