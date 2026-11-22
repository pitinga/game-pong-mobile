# Revisão de segurança Pro — verificação antes dos anúncios

Base: `main` em `5ab0cc127a62e8b43c6ce26ce1c37a3e69ffacea`, revisão de 21/11/2026. Trabalho aplicado diretamente à `main` conforme solicitação do proprietário.

| ID | Status | Causa raiz e correção | Evidência de regressão |
|---|---|---|---|
| A-1N | Corrigido no código e nos fakes | A consulta inicial podia confirmar Free mesmo após um retorno vazio transitório. Agora **toda exibição elegível** exige `verify_free_before_ad(id)`: consulta nativa nova, serializada e associada a ID. Resposta OK sem compra nem pendência, recebida em até 4 s, só permite mostrar enquanto a mesma partida continuar na tela final. Positivo, erro, timeout, falta de ponte, troca de tela e callback tardio descartam o anúncio. | `test_ad_entitlement_preflight.gd`: positivo após reinstalação simulada, fila de consultas, resposta antiga, timeout real da `_process`, cancelamento e confirmação válida. A nova suíte falhava na base antes do ajuste; agora passa. |
| M-2N | Corrigido | A ponte emitia "Pro não encontrado" após toda consulta automática Free. Agora a orientação com conta Google e suporte aparece apenas após `restore()` explícito; no caso de Pro já reconhecido localmente, o próprio jogo preserva a advertência e o botão Restaurar durante a carência. | `test_pro_ad_safety.gd`: consulta automática silenciosa e Restauração com mensagem orientadora. |
| M-3N | Corrigido | `purchase()` confundia abertura do checkout com estado `PENDING` da Play. O jogo possui `CHECKOUT`, sinal `checkout_changed(bool)` e mensagem "Compra em andamento". Somente resposta nativa com `purchase_state == PENDING` produz "Pagamento em análise". Watchdog de 20 s encerra checkout sem retorno, mantém publicidade bloqueada até nova confirmação Free e reconsulta a Play. | `test_pro_billing.gd`: distinção UI e fluxo; `test_ad_entitlement_preflight.gd`: consulta antiga durante checkout, watchdog e PENDING real. |
| B-4N | Decisão de processo, não alterado | Proteção obrigatória de `main` via PR é recomendável, mas o proprietário determinou execução direta na `main`. Nenhuma regra de branch foi alterada nesta rodada. |
| B-5N / B-6N | Limitações conhecidas | Relógio local e cache do cliente não são antifraude. A proteção nova diminui a janela de inconsistência, mas não prova identidade da conta nem elimina respostas erradas repetidas da Play. |

## Testes e ambiente

- Linux, Godot **4.7.2.stable.official.ed1daf0bf**, GDScript headless.
- `godot --headless --path . --editor --import --quit` — aprovado.
- `for test in tests/test_*.gd; do godot --headless --path . --script "res://$test" || exit 1; done` — **11/11 suítes aprovadas**.
- Testes simulados; não houve dispositivo Android, compra real, APK, AAB, anúncio de produção ou medição de desempenho.
- `test_storage_recovery.gd` gera erros esperados de parser de arquivos deliberadamente corrompidos. Outras suítes antigas podem emitir avisos de objetos ao encerrar a árvore.

## Próxima etapa antes da publicidade real

Configurar produto não consumível `pro_unlock`, consentimento real, integração AdMob que respeite `set_ads_allowed(false)` e conta Google de teste. Validar compra, pendência, cancelamento, troca de conta, restauração, reembolso, timeout e reentrada no Android físico. A fila de verificação garante correlação **das consultas iniciadas pelo próprio adaptador**, mas callbacks nativos e comportamento em desconexão ainda precisam de testes integrados. Mantida a opção deliberada de verificar compras no cliente, sem backend, nesta etapa de desenvolvimento.
