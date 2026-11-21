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

O produto reservado na Google Play Console é **`remove_ads`**, do tipo **compra única não consumível**. O próprio menu oferece **Desbloquear Pro** e **Restaurar**; uma compra pendente **não** libera recursos. O jogo consulta as compras ao iniciar, ao voltar do segundo plano e ao solicitar restauração. Compras concluídas são reconhecidas (*acknowledged*), nunca consumidas.

- O adaptador `scripts/play_billing_bridge.gd` usa o plugin oficial **GodotGooglePlayBilling 3.3.0** (incluído em `addons/GodotGooglePlayBilling/`), via Android Gradle Build.
- O fluxo usa o retorno da Google Play para habilitar ou revogar Pro. A última titularidade confirmada é mantida localmente para **não fazer anúncios reaparecerem quando a Play Store estiver temporariamente offline**; uma consulta posterior bem-sucedida prevalece sobre esse cache.
- O cache local não substitui uma verificação antifraude em servidor. Como este jogo não tem backend, a verificação atual é feita pelo cliente Google Play Billing. Se um jogador reinstalar sem conexão e sem cache, precisa conectar-se para restaurar a compra.
- **A compra real depende da criação/ativação do produto `remove_ads` na Play Console e de teste com conta licenciada em um dispositivo Android**. Sem plugin ativo ou sem produto publicado para teste, o botão permanece desativado; o jogo nunca concede Pro por um simples clique.
- Todos os testes de compra usam adaptadores simulados e **não movimentam dinheiro**.

Referências: [Godot — Android In-App Purchases](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html) e [Google Play — Integrate Billing](https://developer.android.com/google/play/billing/integrate).

## Publicidade e outros jogos

- Ainda **não há SDK AdMob nem IDs de produção**. A política local já prepara intersticiais apenas **após partidas concluídas**: um a cada **4 partidas**, mínimo **10 minutos**, máximo **6 impressões por hora**; nunca na primeira partida, durante jogo ou em pausa. Quando Pro está ativo, não solicitar anúncios.
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

O CI executa testes e valida APK/AAB usando **chaves descartáveis**; não disponibiliza arquivos, releases ou caches públicos com builds. Para testar no celular, gere o APK localmente ou distribua por um canal privado. O AAB definitivo deve ser gerado e assinado **localmente** com sua chave privada, nunca publicada no GitHub. A assinatura descartável do CI não serve para a Play Store.

Para um AAB local de publicação, configure as variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` e `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` em um terminal privado e execute:

```bash
godot --headless --path . --install-android-build-template --export-release "Google Play" build/pong-mobile-release.aab
```

Não divulgue keystore, senhas, chaves de API, tokens de compra ou arquivos de publicação no repositório público.

## Preparação da Play Store

1. Criar **somente** o aplicativo `com.pitinga.pongmobile` e cadastrar o produto não consumível `remove_ads`.
2. Testar compra, cancelamento, compra pendente, reconhecimento, restauração, atualização, reinstalação, ausência de rede e reembolso em Android real com licença de teste.
3. Quando o AdMob for integrado, atualizar consentimento, [política de privacidade](docs/privacy-policy.html), Segurança dos Dados e informações sobre anúncios antes de ativar IDs reais.
4. Revisar [ficha da loja](store/listing-pt-BR.md), screenshots e avaliação de conteúdo. A [antiga ficha Pro](store/listing-pro-pt-BR.md) é apenas material histórico.
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
