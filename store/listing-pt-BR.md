# Ficha do Pong Mobile — Google Play (pt-BR)

Preparação da publicação Android. Conferir os itens antes de enviar pelo Play Console.

## Identificação

- Nome do jogo: **Pong Mobile**
- Categoria sugerida: **Jogos → Arcade**
- Pacote Android (identificador definitivo): **com.pitinga.pongmobile**
- Versão preparada: **0.3.5** (código 9)
- Android mínimo: **7.0 / API 24**
- Android alvo: **16 / API 36**
- Arquitetura: **ARM64**
- Idioma inicial: **Português (Brasil)**
- Preço sugerido: **Gratuito**, sem compras internas; publicidade AdMob prevista em futura integração

## Descrição curta (até 80 caracteres)

Pong arcade offline com três dificuldades e partidas rápidas contra o computador.

## Descrição completa (até 4.000 caracteres)

Pong Mobile traz o clássico jogo de raquetes para o seu celular em uma experiência simples, rápida e totalmente offline.

Enfrente o computador, devolva a bola e seja o primeiro a marcar 7 pontos!

Recursos:

- Três níveis de dificuldade: Fácil, Médio e Difícil.
- A bola acelera durante a partida e após cada rebatida.
- Controle da raquete por toque ou arraste na tela.
- Visual arcade com efeitos neon e sons.
- Partidas rápidas para jogar em qualquer lugar.
- Sem compras internas ou necessidade de cadastro.
- Opção para conhecer o Pong Mobile Pro na Google Play, sem publicidade e com modos extras.

Escolha a dificuldade, ajuste sua estratégia e desafie o computador!

## Notas da versão

Versão Free com três dificuldades, aceleração progressiva da bola, controles por toque e divulgação discreta da edição Pro.

## Dados de segurança (conferir no Play Console)

- Coleta/compartilhamento: **não na compilação atual, sem SDK de publicidade**. Após integrar AdMob, revisar conforme as práticas reais do SDK.
- Publicidade: **ainda não ativada**; configurar AdMob e revisar as declarações de conteúdo antes de publicar uma versão com anúncios.
- Compras no aplicativo: **não**.
- Login ou conta de jogador: **não**.
- Contagem local agregada de partidas: **sim**, apenas para respeitar os limites de frequência quando a publicidade for integrada; não contém identificação pessoal nem é transmitida.
- Política de privacidade: `docs/privacy-policy.html` (publicar em URL pública antes do envio).

## Recursos gráficos

- Ícone da loja: `store/icon-512.png` — 512×512.
- Imagem promocional: `store/feature-graphic.png` — 1024×500.
- Capturas reais: `store/screenshots/` (mínimo de duas para celulares).

## Pendências antes de enviar

- Confirmar o identificador definitivo `com.pitinga.pongmobile` e que o app será gratuito.
- Integrar o plugin Android AdMob somente à Free, configurar consentimento e testar em aparelho com IDs de teste; configurar IDs reais antes de monetizar.
- Confirmar que a ficha Pro está pública e habilitar `pong_pro_store_live` no preset Free.
- Definir o e-mail público de suporte no Play Console.
- Publicar a política em URL estática pública e adicioná-la à Play Console.
- Gerar e guardar uma chave de upload privada. **Nunca colocar a chave ou senha no Git.**
- Cadastrar os segredos de assinatura no GitHub Actions.
- Executar o workflow `AAB Google Play` no modo `release` e enviar o AAB no Play Console.
- Preencher classificação indicativa, público-alvo, declarações de conteúdo e segurança de dados.
- Se aplicável à conta pessoal nova, organizar 12 testadores para 14 dias de teste fechado.
