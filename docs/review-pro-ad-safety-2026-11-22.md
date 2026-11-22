# Resposta à revisão — direitos Pro e proteção contra anúncios

Base avaliada: `main` em `d8a8181da04c2e74bdf29132424386810c43d071` (v0.4.0).
Escopo: código de cobrança e permissões de anúncio, interface, testes de simulação e documentação. **Nenhuma compra real, integração AdMob, APK ou AAB foi executada nesta rodada.**

| Achado | Situação após alteração | Causa e correção | Regressão |
|---|---|---|---|
| A-1 — uma negativa revogava Pro | Corrigido por lógica e teste simulado | O booleano era persistido como `false` na primeira consulta vazia. Agora são necessárias ao menos 2 negativas distantes 24 h e 48 h desde a primeira. `pro_owned`, `last_positive_unix`, `negative_first_unix`, `negative_last_unix` e `negative_count` são persistidos com backup. Resposta positiva apaga a suspeita; reembolso legítimo ainda pode revogar. | `test_pro_ad_safety.gd`: negativas no mesmo dia, entre dias antes de 48 h, reinício e reset com positivo; `test_pro_billing.gd`: revogação efetiva e adiamento durante partida/anúncio. |
| A-2 — instalação sem cache tratada como Free apta a anúncios | Corrigido por lógica e teste simulado | Novo estado explícito `UNKNOWN`, `FREE_CONFIRMED`, `PRO`, `PENDING`. Free salvo em disco começa novamente `UNKNOWN`: só resposta válida da Play na sessão atual confirma Free. Intersticial e contagem para frequência são bloqueados antes da confirmação. | `test_pro_ad_safety.gd`: quatro partidas sem consulta, reinício com cache Free, verificação da frequência após confirmação. |
| M-3 — compra pendente | Corrigido por lógica e teste simulado | `PlayBillingBridge` expõe `purchase_pending`; o jogo desabilita anúncios e mostra mensagem de análise sem antecipar o desbloqueio Pro. | `test_pro_billing.gd` e `test_pro_ad_safety.gd`. |
| M-4 — conta Google diferente | Corrigido no texto e no fluxo existente | Consulta vazia orienta verificar a conta Google da compra, tocar em **Restaurar** e buscar suporte. Dono de Pro em carência também vê o botão Restaurar; espaçamento do menu Pro foi compactado para mantê-lo visível. | `test_pro_ad_safety.gd`: mensagem e layout do menu Free/Pro. |
| M-5 — pré-carregamento não bloqueado | Contrato reforçado, aguardando SDK real | O adaptador precisa de `set_ads_allowed(bool)`. A permissão é verdadeira somente se Free foi confirmado nesta sessão **e** houve consentimento. Toda mudança de direito/pendência/consentimento atualiza o adaptador; sem permissão, ele não pode pré-carregar nem exibir. | `test_pro_ad_safety.gd`: falso adaptador registra permissões/pré-cargas/exibições; `test_pong.gd` e `test_ad_lifecycle.gd` atualizados. |
| B-6 — reinstalação offline | Documentado; restrição permanece | Sem cache e sem Google Play, o jogador pode jogar, mas precisa de conexão para restaurar os recursos pagos. Anúncios permanecem bloqueados até confirmar Free. | `test_pro_ad_safety.gd`: estado inicial desconhecido. |
| B-7 — acknowledge | Mantido e documentado | Já existe reconhecimento com tentativas limitadas. Falha prolongada ainda pode resultar em reembolso da Play. | `test_pro_billing.gd`: duplicatas, retry e confirmação. |
| B-8 — reembolso | Comportamento documentado | Revogação confirmada após a carência encerra Pro; conversão durante partida ou anúncio é adiada por segurança. | `test_pro_billing.gd` e `test_pro_ad_safety.gd`. |

## Execução de testes

Ambiente local: Linux, Godot **4.7.2.stable.official.ed1daf0bf**, GDScript, execução headless.

```bash
godot --headless --path . --editor --import --quit
for test in tests/test_*.gd; do godot --headless --path . --script "res://$test" || exit 1; done
git diff --check
```

Resultado local: **importação aprovada, 10/10 suítes concluídas com retorno 0, `git diff --check` sem erros**. Os testes de recuperação de armazenamento produzem avisos/erros esperados ao ler arquivos intencionalmente corrompidos. Algumas suítes de física mostram avisos de liberação de objetos ao encerrar a SceneTree. Nenhuma evidência Android foi coletada.

## Limites e bloqueios para publicidade de produção

1. O SDK AdMob, a tela de consentimento real, o produto `pro_unlock` publicado na Play Console e o e-mail público de suporte ainda não estão configurados. `set_ad_consent_granted(true)` somente é chamado nos testes; o aplicativo distribuído continua **sem anúncios**.
2. É necessário testar no Android com conta de licença: compra nova, pendente, cancelamento, atualização, conexão intermitente, reinstalação, troca de conta, restauração e reembolso. Os fakes não validam os callbacks nativos nem o bloqueio real de pré-carregamento.
3. O cache local é modificável em aparelho comprometido, o relógio do sistema pode ser alterado, e a verificação apenas no cliente não equivale a um serviço antifraude. Sem cache e diante de resposta vazia incorreta da Play, pode haver confirmação Free; a carência protege apenas **compras previamente confirmadas e armazenadas**.
4. A carência de 48 horas mantém Pro temporariamente mesmo após um reembolso legítimo. É uma troca deliberada para priorizar a proteção de compradores contra falhas transitórias.
5. O contrato do adaptador exige que `set_ads_allowed(false)` bloqueie também carregamento; só uma implementação e testes de integração do SDK real poderão confirmar essa garantia.
