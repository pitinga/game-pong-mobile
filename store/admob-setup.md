# Preparação da publicidade — Pong Mobile (app único)

## Estado atual

- A lógica de oportunidade de intersticiais **está implementada e testada** em `scripts/ad_policy.gd`: a cada 4 partidas concluídas, mínimo de 10 minutos e máximo de **6 impressões na janela móvel de 60 minutos**.
- `scripts/pong.gd` oferece intersticial apenas **depois que a partida terminou e a tela final apareceu**, uma tentativa por partida. Não dispara anúncios durante a partida, pausa, primeira partida ou menu. Enquanto a apresentação aceita estiver pendente, os botões de próxima partida/menu ficam indisponíveis até confirmação de fechamento, falha, cancelamento ou recuperação nativa segura. Depois de uma espera excessiva, o jogador pode **fechar o app**, mas não iniciar gameplay atrás de um anúncio desconhecido.
- O contador e os horários das impressões usam **milissegundos Unix** e persistem localmente em `user://pong_free_ad_policy.cfg`, inclusive entre reinicializações. O modo gratuito guarda a contagem de partidas enquanto o SDK não estiver instalado.
- **Ainda não existe integração do SDK nativo AdMob**. A modalidade gratuita não exibe anúncios nem utiliza identificador de publicidade nesta versão. O app pode continuar funcionando offline.
- **Não há segundo pacote Pro.** A compra interna `remove_ads` é consultada no mesmo aplicativo por Google Play Billing. Quando o direito Pro está ativo, não solicitar nem exibir publicidade.

## Para habilitar anúncios antes do lançamento monetizado

1. Criar/validar a conta no [AdMob](https://admob.google.com), registrar `com.pitinga.pongmobile` e configurar um bloco de anúncio do tipo **intersticial**.
2. Utilizar o [Godot AdMob Plugin da Poing Studios](https://github.com/poingstudios/godot-admob-plugin) na versão compatível com Godot 4.7.2, seguindo as instruções de Gradle e Android. O Google lista essa biblioteca de terceiros para integração com Godot; ela não é mantida pela equipe AdMob.
3. Configurar o App ID nativo no Android Manifest do aplicativo único, o identificador da unidade de intersticial e o [consentimento UMP](https://developers.google.com/admob/android/next-gen/privacy) quando aplicável; bloquear a inicialização de anúncios para titulares Pro.
4. Durante testes, utilizar **somente IDs oficiais de teste** (por exemplo, unidade intersticial Android `ca-app-pub-3940256099942544/1033173712`); nunca clicar em anúncios de produção para testar.
5. Implementar um `Node` adaptador do plugin (apenas Free) com o contrato GDScript abaixo, após concluir inicialização, consentimento e pré-carregamento:
   - `is_interstitial_loaded() -> bool`: só retorna `true` quando há intersticial pronto.
   - `show_interstitial(request_id: int) -> bool`: inicia uma solicitação **da tela de fim de partida** e retorna `false` se for recusada. Não enfileirar um anúncio para depois de iniciar a próxima partida.
   - `cancel_interstitial(request_id: int) -> bool`: chamado após 8 segundos sem abertura/impressão e novamente a cada 4 segundos enquanto não houver resposta. Só retornar `true` se o adaptador **garantir** que essa solicitação não poderá apresentar anúncio futuramente.
   - `recover_interstitial(request_id: int) -> bool`: **obrigatório** no adaptador. Reconciliar o estado nativo após falha de cancelamento e após 120 segundos em `SHOWING`, inclusive ao retomar o app. Retornar `true` **somente** se a camada nativa garantir que nenhum anúncio está visível e nenhum anúncio atrasado desse `request_id` poderá surgir. Caso contrário, retornar `false`; o jogo tenta novamente, mantém a partida bloqueada e mostra uma opção para fechar o aplicativo. Simples timeout nunca basta para liberar o jogo.
   - `signal interstitial_opened(request_id: int)`: emitir ao abrir a tela cheia nativa.
   - `signal interstitial_impression(request_id: int)`: emitir no callback nativo **`onAdImpression`**. O jogo persiste essa impressão **uma única vez por ID**, mesmo se o callback chegar tarde. Não registrar no simples pedido de exibição.
   - `signal interstitial_closed(request_id: int)`: emitir ao fechar o anúncio, liberando os botões de partida/menu.
   - `signal interstitial_failed(request_id: int)`: emitir se a apresentação falhar, também liberando os botões sem consumir o crédito.
   - Registrar via `game.set_interstitial_adapter(adapter)` somente quando Pro não estiver ativo. Trocar o adaptador durante uma solicitação exige cancelamento seguro; sem adaptador, não há anúncios. Exemplos de fake: `tests/test_pong.gd` e `tests/test_ad_lifecycle.gd`.
6. Configurar limite adicional de **6 impressões por hora** no [painel do AdMob](https://support.google.com/admob/answer/6244508) e bloquear categorias inapropriadas para o público esperado.
   - Os limites salvos no dispositivo protegem contra reiniciar o aplicativo para zerar a contagem, mas **não são antifraude**: o relógio pode ser alterado pelo usuário. O limite configurado na rede continua sendo necessário.
7. Atualizar a política de privacidade do aplicativo único e o formulário **Segurança dos dados** da Play Store de acordo com as informações coletadas pelo SDK, incluindo consentimento exigido nos países aplicáveis.
8. Validar no **mesmo AAB** os dois estados: sem compra (publicidade elegível) e Pro confirmado (sem anúncios), inclusive após atualização/reinstalação.

## Regra de experiência do jogador

- Não exibir anúncios no início do app, durante partidas, em pausas ou antes de executar o botão **Jogar**.
- Considerar anúncios apenas em transições depois do placar final, respeitando os três limites de frequência (4 partidas, 10 minutos, 6 por hora). Se a rede não tiver anúncio disponível, não interromper o jogo, nem forçar anúncios na próxima tela.
- Não ter anúncios de abertura, banners nem recompensados na primeira versão monetizada.

## Decisões pendentes do usuário

- Conta AdMob aprovada, IDs do aplicativo e bloco de anúncio de produção.
- Público-alvo e categorias de anúncios aceitas.
- Política de privacidade Free final e declaração de coleta do SDK.
