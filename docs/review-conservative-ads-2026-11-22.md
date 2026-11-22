# Proteção conservadora de compradores Pro — Pong Mobile

Base: `main` em `f0a303a7792e39ece28f59b84fe7e5fc04576a2e`.
Decisão do proprietário: **é melhor perder receita temporariamente do que mostrar anúncio a quem já pagou**.

## Regra implementada

1. `UNKNOWN`, `PENDING`, `CHECKOUT` e `PRO`: sem pré-carga e sem anúncios.
2. Uma primeira consulta nativa válida sem compra altera o direito para `FREE_CONFIRMED`, mas **não** autoriza publicidade. Essa consulta recebe um ID único do adaptador de cobrança.
3. Uma partida elegível pode solicitar **outra** consulta, mas não pode mostrar nem carregar publicidade enquanto falta a segunda confirmação independente.
4. Só após **dois IDs de consulta diferentes e negativos na sessão atual**, com consentimento, o jogo autoriza pré-carregamento. Se não houver inventário pronto naquele fim de partida, o jogador segue sem anúncio.
5. Mesmo autorizado a pré-carregar, cada anúncio ainda depende da revalidação nativa exclusiva, `OK` sem Pro, timeout máximo de 4 segundos e permanência na tela de resultado.
6. Respostas duplicadas ou sem consulta ativa não contam como outra confirmação. Falhas e desconexões invalidam o histórico Free da sessão e bloqueiam publicidade. Uma compra Pro positiva interrompe a verificação e apaga o histórico Free. Reinício e troca do adaptador também zeram a contagem.
7. O histórico durável do **dono Pro** permanece separado: pelo menos duas negativas espaçadas por 24 h e carência de 48 h para revogar um Pro anteriormente confirmado. Mesmo depois da revogação, as duas confirmações Free da sessão ainda são exigidas antes de anúncios.

## Testes

- `tests/test_pro_ad_safety.gd`: primeira negativa sem pré-carga, duplicata com mesmo ID, segunda negativa durante oportunidade elegível, reset por pendência, falha e reinstalação, reembolso sem publicidade imediata.
- `tests/test_ad_entitlement_preflight.gd`: ID próprio para cada consulta nativa, resultado antigo não libera anúncio, timeout, callback tardio, cancelamento e checkout.
- `tests/test_pong.gd` e `tests/test_ad_lifecycle.gd`: frequência e ciclo assíncrono mantidos com as duas confirmações simuladas.

Os cenários são simulados em GDScript headless; **não** demonstram o comportamento da Play Store/AdMob reais. Antes de anúncios de produção, validar em Android com conta de teste e consentimento real. Não foram incluídos SDK AdMob ou IDs de produção nesta mudança.
