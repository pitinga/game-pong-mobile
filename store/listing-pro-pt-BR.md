# ARQUIVO HISTÓRICO — NÃO PUBLICAR COMO APLICATIVO SEPARADO

Desde a versão 0.4.0, o Pong tem uma única ficha na Play Store. O Pro é desbloqueado por compra interna não consumível `remove_ads` no pacote `com.pitinga.pongmobile`. As informações abaixo são apenas material de referência da proposta antiga.

# Pong Mobile Pro — ficha de publicação (pt-BR)

- Pacote: `com.pitinga.pongmobile.pro` — confirmar ANTES de criar o app no Play Console.
- Versão: `0.3.5`, código `6`.
- Categoria: Jogos → Arcade.
- Formato: Android App Bundle (AAB), Android 7 / API 24+, ARM64, alvo API 36.
- Monetização: compra única do aplicativo, sem anúncios nem compras internas.

## Descrição curta

Pong offline sem anúncios, com personalização, recordes e modos extras.

## Descrição completa

Pong Mobile Pro traz a diversão do clássico jogo de raquetes sem publicidade e com ferramentas para personalizar cada partida.

Enfrente o computador em três níveis de dificuldade ou desafie outra pessoa no mesmo celular, cada um controlando sua raquete.

Recursos Pro:

- Nenhum anúncio, mesmo durante partidas longas.
- Tamanho da bola e das duas raquetes ajustáveis de 70% a 150%, com restauração imediata dos valores originais.
- Três temas visuais: Neon, Clássico e Verde.
- Modo Sobrevivência: tente alcançar seu recorde de rebatidas antes de perder. A bola mantém a velocidade acumulada mesmo após fazer ponto no computador.
- Partidas de 7, 11 ou 21 pontos contra o computador.
- Dois jogadores locais, com controle por toque em cada metade da tela.
- Estatísticas e recordes guardados no dispositivo, com clássicos padrão separados dos personalizados.
- Contagem de partidas por modo, inclusive Sobrevivência.
- Jogo totalmente offline, sem contas, assinatura mensal ou compras adicionais.

O Pong Mobile Pro funciona em celulares Android 7 ou mais recentes com arquitetura ARM64.

## Recursos gráficos

- `store/icon-pro-512.png`: ícone Pro, 512×512.
- `store/feature-graphic-pro.png`: banner Pro, 1024×500, RGB sem transparência.
- `store/screenshots/pro/`: capturas reais da versão Pro.

## Política e declarações

- Política: `docs/privacy-policy-pro.html` — publicar no GitHub Pages e adicionar a URL no Play Console.
- Dados pessoais coletados/compartilhados pelo aplicativo: não.
- Preferências e estatísticas locais: sim, sem transmissão ou sincronização.
- Contém anúncios: não.
- Compras no aplicativo: não.

## Pendente

- Aprovação da conta Google Play.
- Confirmar nome, preço e pacote definitivo antes de cadastrar.
- Gerar upload keystore privado e assinar o AAB localmente; não usar Secrets de produção no GitHub Actions público.
- Habilitar a página estática de privacidade e preencher informações da loja.
- Realizar testes fechados exigidos para cada aplicativo em conta nova, quando aplicável.
