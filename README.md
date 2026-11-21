# Pong Mobile 🏓

Pong arcade **offline**, feito em **Godot 4 com GDScript**, com duas edições a partir do mesmo projeto: **Free** e **Pro**. A implementação de publicidade na Free está preparada, mas o SDK nativo ainda precisa ser conectado à conta AdMob; até lá, a Free não exibe anúncios. A Pro não terá SDK de publicidade.

## Funcionalidades

- Controle **imediato** da raquete por toque/arraste na tela; no computador, **mouse, W/S ou setas**.
- Três dificuldades reais para o computador: **Fácil, Médio e Difícil** (reação, movimento, antecipação e precisão diferentes), recalibradas conforme o tamanho personalizado das raquetes e da bola.
- Bola acelera continuamente durante a disputa **e** após cada rebatida, até um limite. No Clássico, reinicia após cada ponto; na **Sobrevivência Pro**, mantém a velocidade acumulada após pontuar no computador e reinicia apenas numa nova tentativa.
- Indicador na tela mostra o nível atual e a velocidade da bola.
- Placar até **7 pontos** na Free; a Pro permite 7, 11 ou 21 pontos.
- **Pausa**, continuar, reiniciar e voltar ao menu.
- Efeitos visuais neon e efeitos sonoros sintetizados em tempo de execução.
- Tela horizontal (**paisagem**), otimizada para celulares Android.
- Compatibilidade planejada a partir do **Android 7.0**, apenas **ARM64**.
- Política de privacidade acessível diretamente pelo menu.
- **Pro**: modo Sobrevivência, dois jogadores no mesmo celular (duas metades da tela), temas de cores, tamanhos da bola e raquetes de 70% a 150%, botão de restauração dos padrões e estatísticas locais. Abandonar ou reiniciar uma partida clássica em andamento encerra a sequência de vitórias, **sem adicionar uma derrota**.
- **Free**: botão para conhecer a Pro (mostra "em breve" até publicarmos a ficha da loja) e intersticiais preparados **somente ao encerrar partidas**, a cada 4 partidas concluídas, com intervalo mínimo de 10 minutos e teto de **6 anúncios em qualquer janela de 60 minutos**. Nunca há anúncio na primeira partida, durante o jogo ou em pausa.
- A Free guarda localmente a contagem de partidas concluídas e os limites de frequência entre reinicializações, sem identificador pessoal, rede ou SDK de anúncios na versão atual. Se não houver anúncio disponível, o jogador continua normalmente e a oportunidade fica para um próximo encerramento.
- A interface usa `stretch/aspect=expand` para ocupar telas mais largas ou altas que 16:9; toques da interface (como Pausar) não movimentam a raquete.
- Colisão de bola/raquete com varredura do círculo e contatos nos cantos (inclusive raquete em movimento), sem resgatar bola já atrás da face. Multitouch fixa um dedo por raquete: atravessar o centro não troca o jogador; um novo toque é necessário após ponto ou pausa.

## Executar

1. Instale o [Godot 4.7.2](https://godotengine.org/download/) (versão padrão, sem .NET).
2. No Godot, selecione **Importar** e escolha `project.godot`.
3. Pressione **F6/F5** para iniciar a cena/projeto.

Também é possível executar pelo terminal:

```bash
godot --path .
```

## Testes

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_pong.gd
godot --headless --path . --script res://tests/test_p1_regressions.gd
godot --headless --path . --script res://tests/test_ad_lifecycle.gd
godot --headless --path . --script res://tests/test_aspect_matrix.gd
godot --headless --path . --script res://tests/test_game_rules.gd
```

## Android (APK de teste)

1. No Godot, configure **Editor → Editor Settings → Export → Android** com os caminhos do JDK e do Android SDK.
2. Instale os **Export Templates** da versão 4.7.2 pelo editor.
3. Em **Project → Export**, selecione **Android** (Free) ou **Android Pro** e exporte com **Export With Debug** ativado.

Para gerar pela linha de comando, com o ambiente Android configurado:

```bash
godot --headless --path . --export-debug Android build/pong-mobile-free-debug.apk
godot --headless --path . --export-debug "Android Pro" build/pong-mobile-pro-debug.apk
```

Os commits na branch `main` executam testes e geram **dois APKs de teste** como artefatos do GitHub Actions. Os APKs de debug são próprios para instalação manual, **não** para publicação na Play Store. Ambos possuem identificadores diferentes, podendo coexistir no mesmo celular.

**Atenção:** a chave de assinatura de debug é criada em cada execução do GitHub Actions. Para instalar um APK de uma nova execução sobre o anterior, pode ser necessário desinstalar a versão antiga primeiro, o que apaga os dados locais do app.

## Google Play (AAB de publicação)

Os presets **Google Play** (Free: `com.pitinga.pongmobile`) e **Google Play Pro** (Pro: `com.pitinga.pongmobile.pro`) geram AABs com Gradle. Ambos mantêm **Android 7 / API 24** como mínimo, **API 36** como alvo e apenas **ARM64**.

| Edição | APK de teste | AAB de publicação | Pacote |
| --- | --- | --- | --- |
| Free | `Android` | `Google Play` | `com.pitinga.pongmobile` |
| Pro | `Android Pro` | `Google Play Pro` | `com.pitinga.pongmobile.pro` |

O workflow **AAB Google Play** executa automaticamente uma compilação de **validação com chave descartável**. Esse arquivo de validação **não deve ser enviado à loja**. Para obter o AAB definitivo:

1. No seu computador, crie um keystore de upload exclusivo e faça backup seguro dele. Exemplo no PowerShell 7, com `keytool` no PATH (a senha será solicitada):

   ```powershell
   keytool -genkeypair -keystore "$env:USERPROFILE\pong-upload.jks" -storetype PKCS12 -alias playupload -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Pong Mobile,O=Pitinga,C=BR"
   ```

2. Em **GitHub → Settings → Secrets and variables → Actions**, configure três *Repository secrets*:
   - `PLAY_UPLOAD_KEYSTORE_BASE64`: Base64 do arquivo de keystore (gerado com `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\pong-upload.jks"))` no PowerShell).
   - `PLAY_UPLOAD_ALIAS`: `playupload`.
   - `PLAY_UPLOAD_PASSWORD`: senha escolhida no `keytool`.
3. Execute **Actions → AAB Google Play → Run workflow → release**. O artefato `pong-mobile-free-e-pro-google-play-release` contém **dois AABs assinados**, um para cada ficha na Play Store.
4. Configure o **Google Play App Signing** na primeira versão, envie o AAB, preencha as declarações e siga as exigências de testes da sua conta.

**Nunca** envie o arquivo de keystore nem suas senhas ao GitHub como código, nem os cole nesta conversa. Guarde uma cópia segura da chave. O identificador do pacote será definitivo depois da publicação.

**Publicidade Free:** a política de frequência e o ciclo assíncrono por ID de solicitação já são testados com adaptadores simulados, incluindo timeout, cancelamento seguro e callbacks antigos. **Não há SDK AdMob instalado nem anúncio ativo**. O ponto de integração do adaptador está em `scripts/pong.gd` (`set_interstitial_adapter`). Não publicar a Free afirmando conter anúncios antes de completar [a integração e as declarações necessárias](store/admob-setup.md). Nunca publicar IDs de anúncios de teste como se fossem IDs de produção. A Pro permanece sem SDK de publicidade.

As decisões de jogabilidade ainda em aberto e o resultado da matriz de proporções estão em [Revisão técnica / decisões](docs/technical-review-2026-11-21.md). Mudanças de balanceamento devem ser validadas em Android real antes da publicação.

**Link para a Pro:** o botão da Free ainda informa "em breve". Depois de a ficha Pro estar pública, ativar a feature tag `pong_pro_store_live` no preset Free para habilitar o link oficial à Play Store.

### Materiais para a ficha da loja

- [Ficha Free](store/listing-pt-BR.md) e [ficha Pro](store/listing-pro-pt-BR.md)
- `store/icon-512.png` — ícone 512×512
- `store/feature-graphic.png` — imagem promocional 1024×500
- `store/icon-pro-512.png` e `store/feature-graphic-pro.png` — arte exclusiva da Pro
- `store/screenshots/` e `store/screenshots/pro/` — capturas reais, geradas por **Actions → Capturas Google Play**
- [Política de privacidade](docs/privacy-policy.html) — publicar como página estática pública, por exemplo pelo GitHub Pages, antes de preencher a URL no Play Console
- [Política Pro](docs/privacy-policy-pro.html) — sem anúncios e com dados de configurações/estatísticas armazenados localmente

## Estrutura

```text
assets/icon.svg             Ícone Free; icon-pro.svg da Pro
scenes/main.tscn            Cena principal
scripts/pong.gd             Interface, física, IA, modos e estatísticas
scripts/ad_policy.gd        Regras de frequência de anúncios Free
tests/test_pong.gd          Testes de jogabilidade, edições e anúncios
tests/test_p1_regressions.gd  Regressões de colisão e dedos simultâneos
tests/test_ad_lifecycle.gd   Regressões de callbacks assíncronos de publicidade
tests/test_aspect_matrix.gd  Matriz headless de proporções lógicas
tests/test_game_rules.gd    Regras de Sobrevivência e sequência de vitórias
export_presets.cfg          Presets de exportação Free e Pro
.github/workflows/          Testes, APKs e AABs
docs/                      Políticas de privacidade Free e Pro
store/                      Textos e artes da Google Play
```

## Licença

MIT. Consulte [LICENSE](LICENSE).
