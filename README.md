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
- O fluxo usa o retorno da Google Play para habilitar ou revogar Pro. A última titularidade confirmada é mantida localmente para **não fazer anúncios reaparecerem quando a Play Store estiver temporariamente offline**; uma consulta posterior bem-sucedida prevalece sobre esse cache.
- O adaptador tenta reconectar após interrupções com espera progressiva (máximo cinco tentativas automáticas) e novamente quando o jogador toca em Restaurar ou retorna ao aplicativo, sem abrir conexões duplicadas durante uma tentativa. Consulta os detalhes do produto antes das compras e possui *watchdog* de 5 s para restaurar a compra mesmo se a consulta de preço travar. Erros de *acknowledge* são repetidos de modo limitado. Após confirmação de pagamento, consultas vazias da loja não revogam o Pro durante até 5 minutos de sincronização; uma consulta válida após a janela pode revogar. Mudanças de regras e raquetes por revogação são adiadas até a partida terminar ou o jogador ir ao menu.
- O cache local não substitui uma verificação antifraude em servidor. Para a **versão de desenvolvimento 0.4.0**, a decisão é manter a verificação apenas no cliente, sem backend: simplifica o jogo, mas permite adulteração em aparelho modificado. A aceitação definitiva desse risco para monetização real precisa ser confirmada pelo proprietário antes de publicar. Se um jogador reinstalar sem conexão e sem cache, precisa conectar-se para restaurar a compra.
- **A compra real depende da criação/ativação do produto `pro_unlock` na Play Console e de teste com conta licenciada em um dispositivo Android**. Sem plugin ativo ou sem produto publicado para teste, o botão permanece desativado; o jogo nunca concede Pro por um simples clique.
- O projeto mantém a permissão Android **INTERNET** porque a [instalação oficial do plugin](https://github.com/godot-sdk-integrations/godot-google-play-billing/blob/master/docs/installation.md) a solicita para Google Play Billing. Isso não impede partidas offline; conectividade é necessária para consultar preços, comprar e restaurar sem cache.
- Todos os testes de compra usam adaptadores simulados e **não movimentam dinheiro**.

Referências: [Godot — Android In-App Purchases](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html) e [Google Play — Integrate Billing](https://developer.android.com/google/play/billing/integrate).

## Publicidade e outros jogos

- Ainda **não há SDK AdMob nem IDs de produção**. A política local já prepara intersticiais apenas **após partidas concluídas**: um a cada **4 partidas**, mínimo **10 minutos**, máximo **6 impressões por hora**; nunca na primeira partida, durante jogo ou em pausa. Quando Pro está ativo, não solicitar anúncios.
- Quando já existe adaptador de anúncios, ele é mantido ao ativar Pro, mas não é chamado para mostrar anúncios; se a titularidade for revogada, a versão Free poderá reutilizá-lo sem reiniciar o app. O futuro SDK deve respeitar o consentimento e não carregar publicidade para Pro.
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
- `tests/test_*.gd` — demais testes de física, jogabilidade e persistência.
- `.github/workflows/` — testes, exportação validada e capturas, sem distribuição pública de binários.
- `store/`, `docs/` — textos, artes e documentação técnica.

## Licença

MIT — consulte [LICENSE](LICENSE). O plugin Google Play Billing incluído possui [licença própria MIT](addons/GodotGooglePlayBilling/LICENSE).
