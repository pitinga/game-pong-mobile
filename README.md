# Pong Mobile 🏓

Jogo de Pong em **Godot 4.7.2 / GDScript**, com um único aplicativo Android: **grátis** e desbloqueio **Pro permanente** por compra interna da Google Play. Não existe mais um aplicativo Pro separado.

## Jogabilidade

- Clássico contra o computador, com dificuldade Fácil, Médio ou Difícil e bola que acelera ao longo da partida.
- Controle direto por toque, com captura multitouch estável para o modo local de dois jogadores; mouse e teclado no desktop.
- Física com detecção contínua dos impactos (paredes, faces, cantos das raquetes e gols), incluindo tempo restante do passo.
- Saque, pausa, reinício, ajustes de proporção de tela e efeitos neon/sons sintetizados.
- **Pro** desbloqueia Sobrevivência, dois jogadores locais, configurações de 7/11/21 pontos, temas, tamanho da bola/raquete (70%–150%) com restauração dos padrões e estatísticas locais, além de remover anúncios.
- Em Sobrevivência, o saque mantém a velocidade acumulada após pontos no computador. No Clássico, abandono/reinício explícito ou encerramento do processo quebra a sequência sem registrar derrota artificial.

## Pro: compra única dentro do app

O ID definitivo **a cadastrar (ainda não criado)** na Google Play Console é **`pro_unlock`**, do tipo **compra única não consumível**. IDs criados não podem ser alterados depois. O próprio menu oferece **Desbloquear Pro** (com preço localizado retornado pela Play) e **Restaurar**; uma compra pendente **não** libera recursos. O jogo consulta as compras ao iniciar, ao voltar do segundo plano e ao solicitar restauração. Compras concluídas são reconhecidas (*acknowledged*), nunca consumidas.

- O adaptador `scripts/play_billing_bridge.gd` usa o plugin oficial **GodotGooglePlayBilling 3.3.0** (incluído em `addons/GodotGooglePlayBilling/`), via Android Gradle Build. Origem: [release v3.3.0](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0), commit upstream `e494f37`, ZIP da release SHA-256 `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568`. Os dois `.aar` têm SHA-256 em [SHA256SUMS](addons/GodotGooglePlayBilling/SHA256SUMS), verificados no CI.
- O fluxo usa o retorno da Google Play para habilitar ou revogar Pro. A última titularidade positiva é mantida localmente para **não fazer anúncios reaparecerem por falha transitória da Play Store**. Uma resposta negativa isolada não revoga o Pro armazenado: são necessárias **ao menos duas verificações negativas separadas por 24 horas e um intervalo mínimo de 48 horas desde a primeira**. O histórico fica no dispositivo, inclusive após reiniciar o app, e toda confirmação positiva o apaga. Uma revogação legítima após esse prazo volta ao Free.
- O adaptador tenta reconectar após interrupções com espera progressiva (máximo cinco tentativas automáticas) e novamente quando o jogador toca em Restaurar ou retorna ao aplicativo, sem abrir conexões duplicadas durante uma tentativa. Consulta os detalhes do produto antes das compras e possui *watchdog* de 5 s para restaurar a compra mesmo se a consulta de preço travar. Erros de *acknowledge* são repetidos de modo limitado enquanto o app roda; se o pagamento não for reconhecido a tempo, a Play pode reembolsá-lo. Após confirmação de pagamento na mesma sessão, consultas vazias da loja são rechecadas durante até 5 minutos de sincronização; a proteção persistente de 48 horas também se aplica. Mudanças de regras e raquetes por revogação são adiadas até a partida terminar ou o jogador ir ao menu.
- Ao iniciar sem um Pro confirmado no cache, a titularidade começa como **desconhecida**. Só fica Free confirmada depois de uma consulta válida na **sessão atual**. Uma compra **pendente de aprovação** desativa anúncios, mas ainda não libera recursos Pro. Se a loja não encontrar a compra, confira qual conta Google foi usada na Play Store, toque em **Restaurar** e, se necessário, abra um pedido de suporte. Após reinstalação offline sem cache, os recursos Pro só reaparecem depois de uma restauração online.
- O fluxo diferencia **compra em andamento** (janela de checkout, ainda sem pagamento confirmado) de **pagamento pendente** (a Play retornou `PENDING`). Ambos bloqueiam publicidade; um watchdog de 20 s encerra o estado de checkout sem callback e volta a consultar a Play. A orientação de "Pro não encontrado" aparece apenas quando o jogador toca em **Restaurar**, e não em toda abertura Free.
- O cache local não substitui uma verificação antifraude em servidor. Para a **versão de desenvolvimento 0.4.0**, a decisão é manter a verificação apenas no cliente, sem backend: simplifica o jogo, mas permite adulteração em aparelho modificado. A aceitação definitiva desse risco para monetização real precisa ser confirmada pelo proprietário antes de publicar. Se um jogador reinstalar sem conexão e sem cache, precisa conectar-se para restaurar a compra.
- **A compra real depende da criação/ativação do produto `pro_unlock` na Play Console e de teste com conta licenciada em um dispositivo Android**. Sem plugin ativo ou sem produto publicado para teste, o botão permanece desativado; o jogo nunca concede Pro por um simples clique.
- O projeto mantém a permissão Android **INTERNET** porque a [instalação oficial do plugin](https://github.com/godot-sdk-integrations/godot-google-play-billing/blob/master/docs/installation.md) a solicita para Google Play Billing. Isso não impede partidas offline; conectividade é necessária para consultar preços, comprar e restaurar sem cache.
- Todos os testes de compra usam adaptadores simulados e **não movimentam dinheiro**.

Referências: [Godot — Android In-App Purchases](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html) e [Google Play — Integrate Billing](https://developer.android.com/google/play/billing/integrate).

## Publicidade e outros jogos

- Ainda **não há SDK AdMob nem IDs de produção**. A política local já prepara intersticiais apenas **após partidas concluídas**: um a cada **4 partidas**, mínimo **10 minutos**, máximo **6 impressões por hora**; nunca na primeira partida, durante jogo ou em pausa.
- O futuro adaptador deverá implementar `set_ads_allowed(bool)` e **não pré-carregar nem exibir anúncios** quando o direito for desconhecido, Pro ou pendente, ou quando faltar consentimento. O jogo inicia com consentimento desativado; uma integração real deverá obtê-lo e chamar `set_ad_consent_granted(true)` somente quando permitido. O adaptador pode permanecer conectado ao ativar Pro, mas deve parar de carregar publicidade; após revogação confirmada, poderá voltar a ser utilizado.
- **Política conservadora de receita:** o jogador só pode receber pré-carregamento após **duas consultas negativas independentes** da Play **nesta sessão**. A ponte atribui um ID a cada consulta nativa; resposta duplicada não conta. A primeira negativa permite somente consultar de novo ao fim de uma partida elegível, sem carregar ou mostrar anúncio. Se a segunda chegar nessa oportunidade, o carregamento poderá começar, mas a exibição será descartada caso ainda não haja inventário pronto. Falha/desconexão, checkout, pendência, troca do adaptador ou reinício zeram essas confirmações. A prioridade é perder impressões, não irritar quem já comprou Pro.
- **Confirmação antes de cada anúncio:** quando a frequência permitir um intersticial, o jogo solicita à ponte Billing uma consulta **nova e identificada** de compras. Uma fila serializa consultas para não confundir o retorno de um refresh anterior com a verificação do anúncio. Só uma resposta `OK`, sem Pro/PENDING, recebida em até **4 segundos** e ainda na tela de resultado permite exibição. Falha, desconexão, ausência da ponte, timeout ou navegação descartam a oportunidade, sem interromper a partida. **Nenhuma consulta se repete por cada frame; apenas em partidas elegíveis.**
- A integração AdMob futura deverá implementar consentimento e o ciclo assíncrono seguro documentado em [store/admob-setup.md](store/admob-setup.md), sem bloquear indevidamente a jogabilidade.
- O menu contém a área **“Instale outros jogos”**. O catálogo `RELEASED_GAME_CATALOG` em `scripts/pong.gd` recebe links **reais da Google Play** conforme os outros jogos forem publicados; o próprio Pong e URLs fora da Play são rejeitados. Enquanto o catálogo estiver vazio, o menu informa **“Em breve”** e não abre links inexistentes.

## Executar e testar

Requer Godot 4.7.2. Abra `project.godot` ou, no terminal:

```bash
godot --headless --path . --editor --import --quit
godot --path .
```

Testes automatizados (incluindo compra, restauração, callbacks de anúncios, física e multitouch):

```bash
for test in tests/test_*.gd; do godot --headless --path . --script "res://$test" || exit 1; done
```

## Exportação Android

| Artefato | Preset | Pacote Android |
|---|---|---|
| APK de teste | `Android` | `com.pitinga.pongmobile` |
| AAB Google Play | `Google Play` | `com.pitinga.pongmobile` |

Ambos usam **Android 7 / API 24 mínimo, API 36 alvo e ARM64**, com build Gradle para o plugin Billing. A versão preparada é **0.4.0 (código 10)**. Configure Android SDK, JDK 17 e os Export Templates do Godot antes de exportar.

```bash
godot --headless --path . --install-android-build-template --export-debug Android build/pong-mobile-debug.apk
```

O CI executa testes e valida APK/AAB usando **chaves descartáveis**; não disponibiliza arquivos, releases ou caches públicos com builds. Também confere a permissão `com.android.vending.BILLING`, o registro e as classes do plugin no pacote exportado. Para testar no celular, gere o APK localmente ou distribua por um canal privado. O AAB definitivo deve ser gerado e assinado **localmente** com sua chave privada, nunca publicada no GitHub. A assinatura descartável do CI não serve para a Play Store.

Para um AAB local de publicação, configure as variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` e `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` em um terminal privado e execute:

```bash
godot --headless --path . --install-android-build-template --export-release "Google Play" build/pong-mobile-release.aab
```

Não divulgue keystore, senhas, chaves de API, tokens de compra ou arquivos de publicação no repositório público.

## Preparação da Play Store

1. Criar **somente** o aplicativo `com.pitinga.pongmobile` e cadastrar o produto não consumível `pro_unlock` (verificar o ID antes de salvar no Console).
2. Testar compra, cancelamento, compra pendente, reconhecimento, restauração, atualização, reinstalação, ausência de rede e reembolso em Android real com licença de teste.
3. Quando o AdMob for integrado, atualizar consentimento, [política de privacidade](docs/privacy-policy.html), Segurança dos Dados e informações sobre anúncios antes de ativar IDs reais.
4. Revisar [ficha da loja](store/listing-pt-BR.md), screenshots, avaliação de conteúdo e informar **e-mail público de suporte real** no Play Console. O contato por issues no GitHub é apenas um canal adicional. A [antiga ficha Pro](store/listing-pro-pt-BR.md) é material histórico.
5. Cumprir testes fechados e obter acesso de produção conforme os requisitos aplicáveis à sua conta Play Console.

## Estrutura

- `scripts/pong.gd` — física, interface, modos e integração dos adaptadores.
- `scripts/play_billing_bridge.gd` — integração com Google Play Billing, sem IDs de produção.
- `addons/GodotGooglePlayBilling/` — plugin oficial 3.3.0 (licença MIT).
- `scripts/ad_policy.gd` — limites de intersticiais.
- `tests/test_pro_billing.gd` — fluxo simulado de compra, restauração, offline, revogação e catálogo.
- `tests/test_pro_ad_safety.gd` — proteção de anúncios no Pro, carência entre negativas, pendências e consentimento simulado.
- `tests/test_ad_entitlement_preflight.gd` — confirmação fresca antes de cada anúncio, callbacks antigos, timeout, checkout e cancelamento.
- [Decisão de proteção adicional de compradores](docs/review-conservative-ads-2026-11-22.md) — duas negativas independentes antes de pré-carga, evidências e riscos residuais.
- `tests/test_*.gd` — demais testes de física, jogabilidade e persistência.
- `.github/workflows/` — testes, exportação validada e capturas, sem distribuição pública de binários.
- `store/`, `docs/` — textos, artes e documentação técnica.

## Licença

MIT — consulte [LICENSE](LICENSE). O plugin Google Play Billing incluído possui [licença própria MIT](addons/GodotGooglePlayBilling/LICENSE).
