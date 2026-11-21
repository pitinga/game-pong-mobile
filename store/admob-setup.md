# Preparação da publicidade — Pong Mobile Free

## Estado atual

- A lógica de oportunidade de intersticiais **está implementada e testada** em `scripts/ad_policy.gd`: a cada 4 partidas concluídas, mínimo de 10 minutos e máximo de **6 impressões na janela móvel de 60 minutos**.
- `scripts/pong.gd` oferece intersticial apenas **depois que a partida terminou e a tela final apareceu**, uma tentativa por partida. Não dispara anúncios durante a partida, pausa, primeira partida ou menu.
- O contador e os horários das impressões usam **milissegundos Unix** e persistem localmente em `user://pong_free_ad_policy.cfg`, inclusive entre reinicializações. A Free já guarda apenas a contagem de partidas enquanto o SDK não estiver instalado.
- **Ainda não existe integração do SDK nativo AdMob**. A Free não exibe anúncios nem utiliza identificador de publicidade nesta versão. O app pode continuar funcionando offline.
- A edição Pro **não deve conter** SDK, permissões ou inicialização de anúncios. O pacote Android Pro e o preset são distintos.

## Para habilitar anúncios antes do lançamento monetizado

1. Criar/validar a conta no [AdMob](https://admob.google.com), registrar `com.pitinga.pongmobile` e configurar um bloco de anúncio do tipo **intersticial**.
2. Utilizar o [Godot AdMob Plugin da Poing Studios](https://github.com/poingstudios/godot-admob-plugin) na versão compatível com Godot 4.7.2, seguindo as instruções de Gradle e Android. O Google lista essa biblioteca de terceiros para integração com Godot; ela não é mantida pela equipe AdMob.
3. Configurar o App ID nativo no Android Manifest somente do build Free, o identificador da unidade de intersticial e o [consentimento UMP](https://developers.google.com/admob/android/next-gen/privacy) quando aplicável.
4. Durante testes, utilizar **somente IDs oficiais de teste** (por exemplo, unidade intersticial Android `ca-app-pub-3940256099942544/1033173712`); nunca clicar em anúncios de produção para testar.
5. Implementar um `Node` adaptador do plugin (apenas Free) com o contrato GDScript abaixo, após concluir inicialização, consentimento e pré-carregamento:
   - `is_interstitial_loaded() -> bool`: só retorna `true` quando há intersticial pronto.
   - `show_interstitial() -> bool`: solicita exibição **imediata** na tela de fim de partida; retorna `false` em falha, sem consumir a oportunidade. Não enfileirar apresentação para depois.
   - `signal interstitial_impression`: emitir no callback nativo **`onAdImpression`**. O jogo registra e persiste a impressão nesse instante, nunca no simples pedido de exibição.
   - `signal interstitial_closed`: emitir no fechamento ou na falha de apresentação, liberando qualquer pedido pendente sem consumo de partida.
   - Registrar o adaptador via `game.set_interstitial_adapter(adapter)` somente na Free. Sem adaptador, o comportamento é silencioso (sem anúncios). Os testes de `tests/test_pong.gd` mostram a implementação simulada do contrato.
6. Configurar limite adicional de **6 impressões por hora** no [painel do AdMob](https://support.google.com/admob/answer/6244508) e bloquear categorias inapropriadas para o público esperado.
   - Os limites salvos no dispositivo protegem contra reiniciar o aplicativo para zerar a contagem, mas **não são antifraude**: o relógio pode ser alterado pelo usuário. O limite configurado na rede continua sendo necessário.
7. Atualizar a política de privacidade Free e o formulário **Segurança dos dados** da Play Store de acordo com as informações coletadas pelo SDK, incluindo consentimento exigido nos países aplicáveis.
8. Validar o AAB Free assinado com IDs reais e o AAB Pro completamente livre do SDK de anúncios antes de enviar à loja.

## Regra de experiência do jogador

- Não exibir anúncios no início do app, durante partidas, em pausas ou antes de executar o botão **Jogar**.
- Considerar anúncios apenas em transições depois do placar final, respeitando os três limites de frequência (4 partidas, 10 minutos, 6 por hora). Se a rede não tiver anúncio disponível, não interromper o jogo, nem forçar anúncios na próxima tela.
- Não ter anúncios de abertura, banners nem recompensados na primeira versão monetizada.

## Decisões pendentes do usuário

- Conta AdMob aprovada, IDs do aplicativo e bloco de anúncio de produção.
- Público-alvo e categorias de anúncios aceitas.
- Política de privacidade Free final e declaração de coleta do SDK.
