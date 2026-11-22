# Devolutiva ao revisor — unificação Pong Free/Pro

Base revisada: `34847d784a95a4f59cbad4e0cfcb686b246bcaaa`, branch `feat/unified-pro-iap`, PR #4.

## Correções desta rodada

| ID | Status | Causa e correção | Evidência automatizada |
|---|---|---|---|
| P1-01 | Corrigido no adaptador | A conexão caía sem tentativa posterior. Retry progressivo de 1/2/4/8/16 s (máximo 5) e nova conexão manual em `refresh()`/retomada. | `test_pro_billing.gd`: disconnect, connect_error, recomeço em refresh. |
| P1-02 | ID definido | `remove_ads` não descrevia todos os recursos. Novo ID **`pro_unlock`**; deve ser criado exatamente assim no Play Console, somente após a revisão. | Testes de compra rejeitam outros IDs e usam `pro_unlock`. |
| P1-03 | Verificação no CI | Build apenas compilava; workflows agora inspecionam permissão BILLING, metadados nativos e classe DEX do plugin no APK e no AAB. | Verificação de artefato no `android.yml` e `google-play.yml`. **Resultado de CI deve ser observado após push.** |
| P2-04 | Rastreabilidade registrada | AARs não documentavam origem. README aponta release oficial 3.3.0 (`e494f37`), SHA do ZIP original e SHA-256 individuais; workflows verificam hashes locais. | `sha256sum -c addons/GodotGooglePlayBilling/SHA256SUMS` executado nos jobs. |
| P2-05 | Corrigido no menu | O adaptador ignorava a oferta. Agora seleciona a opção padrão de compra avulsa, extrai `formatted_price` e exibe no botão, sem inventar valor quando indisponível. | Teste simula `R$ 4,99` e verifica botão e `purchase_option_id`. |
| P2-06 | Mantido com justificativa | Permissão INTERNET segue indicada pela documentação oficial de instalação do plugin Billing; partidas continuam offline e acesso à rede é necessário para consultar a Play. | README e política de privacidade esclarecem finalidade. |
| P2-07 | Corrigido | Revogação alterava regras/raquetes durante partida. Cache remoto atualiza imediatamente, mas mudança de regras só vale no menu/reinício. Anúncio já aceito pode terminar antes de aplicar transição. | Testes: dois jogadores, reinício em partida e anúncio assíncrono. |
| P2-08 | Corrigido com política de reconciliação | Duas respostas vazias rápidas apagavam compra recém-confirmada. Após callback PURCHASED, consultas vazias ficam em quarentena por **5 minutos**, com reconsultas em intervalos crescentes (5 a 60 s). Consulta positiva encerra quarentena; após o prazo uma consulta OK vazia pode revogar. | Testes: duas respostas vazias, vencimento simulado da janela e reembolso posterior. |
| P2-09 | Coberto estaticamente | Menu Free tinha teste de layout mas não com preço preenchido. | Verifica painel Free completo com preço em 530 px e teste Pro existente. Android real permanece pendente. |

## Decisões e limites

- **P3-10:** por enquanto, titularidade fica em cache local; não existe backend/Play Integrity. Risco residual de adulteração em aparelho modificado aceito provisoriamente para um jogo simples, mas precisa de decisão do proprietário antes da publicação.
- **P3-11:** o botão “EM BREVE” segue desabilitado até que existam URLs de jogos efetivamente publicados. Isso atende ao pedido de divulgação cruzada sem links fictícios.
- **P3-12:** política menciona Google Play Billing, armazenamento local e permissão de internet. Um e-mail público real de suporte ainda precisa ser cadastrado no Play Console; issues não devem ser o único canal.
- **Não há SDK AdMob nem IDs de produção.** O código de política de anúncios permanece simulado.
- **Sem compra real:** não foram executados testes nativos com conta de licença ou produto Play ativado; testes headless simulam callbacks, não validam cobrança, reconciliação, ciclo de vida nativo nem preço real. Antes da produção, testar Android 7/ARM64 e Android recente, compra, cancelamento, pendente, reembolso, reinstalação e troca de conta.
- **Janela de sincronização:** uma consulta vazia **após 5 minutos** pode revogar o Pro; isso evita retenção indefinida após reembolso, mas pode causar revogação temporária se a Play Store demorar excepcionalmente para reconciliar. Reavaliar com teste nativo.

## Ambiente e comando de validação local

- Godot `4.7.2.stable.official.ed1daf0bf` em Linux.
- Importação: `godot --headless --path . --editor --import --quit` (exit 0).
- Suítes: `for test in tests/test_*.gd; do godot --headless --path . --script "res://$test" || exit 1; done` (9/9 aprovadas na rodada local).
- Nenhum APK/AAB de publicação foi assinado com chave real ou disponibilizado publicamente; CI usa chave descartável e runner efêmero.

## Próximo passo

Esperar o CI da atualização do PR #4, solicitar segunda revisão dos IDs acima e **não mesclar** antes de aceite. Depois, validar pagamento real e comportamento no Android com o produto `pro_unlock` configurado.

## Segunda revisão (commit-base `773b6ae`)

| Achado | Tratamento na rodada seguinte |
|---|---|
| M-3.1 | `_on_connected` solicita primeiro `queryProductDetails`; `_on_product_details` consulta compras mesmo em erro. Um watchdog de 5 s consulta compras se nenhum callback de detalhes chegar. Não sacrificar restauração de Pro por falta de preço. |
| M-3.2 | Estruturas/nomes de campos confirmados **estaticamente nos bytecodes dos dois AARs v3.3.0**: `one_time_purchase_offer_details_list`, `formatted_price`, `purchase_option_id`, `offer_id` e `product_id`. Isso reduz o risco de chave inexistente, mas não substitui consultar um produto real no Android. |
| B-3.3 | O adaptador de anúncios não é mais descartado ao conceder Pro; pedidos continuam proibidos enquanto `is_pro`, e revogação reutiliza o adaptador. Coberto com fake de anúncio nos testes. Nenhum SDK de anúncios real foi ativado. |
| B-3.4 | Removida transição intermediária forçada `state = MENU` durante `_start_match`. `_settle_pro_transition(true)` aplica pendências exclusivamente entre partidas, sem acionar o menu. |
| B-3.5 | Introduzido estado `_connecting` e watchdog de conexão de 20 s; `refresh()` não repete `startConnection` se houver tentativa ativa. Coberto por teste com fake nativo. |
| B-3.6 | O commit upstream, a URL de release oficial, SHA-256 do ZIP de distribuição e hashes individuais dos AARs constam no README. A validação `sha256sum -c` confirma integridade dos arquivos versionados, **não autentica a origem** por si só. O ZIP foi baixado do release oficial na integração inicial; nesta rodada não foi feito novo download independente. |

**Risco P3-10:** esta PR prepara a versão de desenvolvimento sem faturamento ativo. A verificação apenas no cliente, com cache adulterável, é uma escolha de escopo **provisória para 0.4.0**, não afirmação de segurança antifraude. Antes de habilitar compras reais, o proprietário deverá aceitar expressamente essa limitação ou solicitar verificação em servidor.

**Condição de CI para merge:** o workflow de AAB passou a rodar também em `pull_request` (chave descartável, nenhum artefato distribuído). O resultado real do job AAB deve ser confirmado antes do merge.
