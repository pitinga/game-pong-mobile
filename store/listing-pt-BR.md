# Ficha do Pong Mobile — Google Play (pt-BR)

Preparação da publicação Android. Conferir os itens antes de enviar pelo Play Console.

## Identificação

- Nome do jogo: **Pong Mobile**
- Categoria sugerida: **Jogos → Arcade**
- Pacote Android (identificador definitivo): **com.pitinga.pongmobile**
- Versão preparada: **0.4.0** (código 10)
- Android mínimo: **7.0 / API 24**
- Android alvo: **16 / API 36**
- Arquitetura: **ARM64**
- Idioma inicial: **Português (Brasil)**
- Preço sugerido: **Gratuito**, com compra interna única **Pro (pro_unlock)**; publicidade AdMob prevista após integração

## Descrição curta (até 80 caracteres)

Pong arcade offline com três dificuldades e partidas rápidas contra o computador.

## Descrição completa (até 4.000 caracteres)

Pong Mobile traz o clássico jogo de raquetes para o seu celular, com partidas rápidas e jogabilidade offline.

Enfrente o computador, devolva a bola e seja o primeiro a marcar 7 pontos!

Recursos:

- Três níveis de dificuldade: Fácil, Médio e Difícil.
- A bola acelera durante a partida e após cada rebatida.
- Controle da raquete por toque ou arraste na tela.
- Visual arcade com efeitos neon e sons.
- Partidas rápidas para jogar em qualquer lugar.
- Desbloqueio Pro permanente, dentro do próprio aplicativo, para jogar sem anúncios.
- No Pro: Sobrevivência, dois jogadores locais, temas, tamanhos da bola e das raquetes e estatísticas.
- Sem necessidade de cadastro no jogo; a compra é gerenciada pela Google Play.
- Uma compra Pro existente pode ser recuperada pelo botão Restaurar, com a mesma conta Google utilizada na compra.

Escolha a dificuldade, ajuste sua estratégia e desafie o computador!

## Notas da versão

Uma única versão Android: gratuito + desbloqueio Pro por compra no aplicativo.

## Dados de segurança (conferir no Play Console)

- Coleta/compartilhamento: **não na compilação atual, sem SDK de publicidade**. Após integrar AdMob, revisar conforme as práticas reais do SDK.
- Publicidade: **ainda não ativada**; configurar AdMob e revisar as declarações de conteúdo antes de publicar uma versão com anúncios.
- Compras no aplicativo: **sim**, desbloqueio Pro permanente pela Google Play Billing. Configurar produto não consumível antes de disponibilizar a compra.
- Login ou conta de jogador: **não**.
- Contagem local agregada de partidas: **sim**, apenas para limitar publicidade. Preferências Pro, estatísticas, última titularidade confirmada e datas/quantidade de verificações negativas são armazenadas localmente.
- Pagamentos: processados pela Google Play. Consultar e revisar as declarações de tratamento do SDK e da plataforma antes da publicação.
- Política de privacidade: `docs/privacy-policy.html` (publicar em URL pública antes do envio).

## Recursos gráficos

- Ícone da loja: `store/icon-512.png` — 512×512.
- Imagem promocional: `store/feature-graphic.png` — 1024×500.
- Capturas reais: `store/screenshots/` (mínimo de duas para celulares).

## Pendências antes de enviar

- Confirmar o identificador definitivo `com.pitinga.pongmobile` e que o app será gratuito.
- Criar produto interno **não consumível** `pro_unlock` no mesmo aplicativo, ativar e testar compra, pendência, restauração, atualização e reembolso. Usar somente licenças de teste na validação inicial.
- Validar o plugin **GodotGooglePlayBilling 3.3.0** em um Android com Google Play e configurar o produto para habilitar a compra.
- Explicar no suporte: usar a **mesma conta Google** da compra e tocar em **Restaurar**; após reinstalação sem cache e offline pode ser necessário conectar-se. Uma consulta vazia isolada mantém Pro previamente confirmado, mas reembolso legítimo deve revogar o direito depois da carência.
- Integrar o SDK AdMob ao aplicativo único, respeitando o direito Pro para não solicitar anúncios; configurar consentimento, testar IDs de teste e ativar IDs reais somente na publicação monetizada.
- Ativar links "Conheça nossos jogos" apenas para aplicativos já publicados na Play Store.
- Definir o e-mail público de suporte no Play Console.
- Publicar a política em URL estática pública e adicioná-la à Play Console.
- Gerar e guardar uma chave de upload privada. **Nunca colocar a chave ou senha no Git.**
- Assinar e exportar o AAB localmente com a chave privada, conforme o README; o workflow público faz somente validação com chave descartável.
- Enviar o AAB local pelo Play Console, sem publicá-lo como artefato de repositório público.
- Preencher classificação indicativa, público-alvo, declarações de conteúdo e segurança de dados.
- Se aplicável à conta pessoal nova, organizar 12 testadores para 14 dias de teste fechado.
