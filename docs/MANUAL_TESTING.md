# Roteiro de teste manual — ocico store

Roteiro para conferir à mão, no navegador, tudo o que a loja faz hoje. Cada item
diz **o que fazer** e **o que deve acontecer**. Marque `[x]` conforme for
passando; anote o que divergir.

## 0. Preparação

```bash
docker compose up -d                       # Postgres
export PATH="$HOME/.local/share/gem/ruby/3.4.0/bin:$PATH"
set -a; . ./.env; set +a                   # Stripe, Mercado Pago, Melhor Envio (sandbox)
bin/rails db:seed                          # idempotente
EXECJS_RUNTIME=Node bin/dev                # loja em http://localhost:3000, admin em /admin
```

Em outro terminal, para os webhooks do cartão:

```bash
stripe listen --events payment_intent.succeeded,payment_intent.payment_failed,payment_intent.canceled,charge.refunded \
  --forward-to http://localhost:3000/solidus_stripe/test/webhooks
```

- Admin: `admin@example.com` / `test123`.
- **E-mails em desenvolvimento não são entregues**: o conteúdo de cada e-mail
  aparece no log do servidor (`log/development.log`, procure por `Subject:`).
- Pix/Boleto não sincronizam sozinhos em dev: depois de pagar no sandbox, rode
  `bin/rails mercado_pago:sync`.

Dados úteis:

| Uso | Valor |
|---|---|
| CEP de destino comum | `01310-100` (São Paulo), `20040-020` (Rio) |
| CEP remoto (menos transportadoras) | `69900-000` (Rio Branco) — não autocompleta, preencha à mão |
| CEP inexistente | `99999-999` |
| Cartão aprovado | `4242 4242 4242 4242`, validade futura, CVC qualquer |
| Cartão recusado | `4000 0000 0000 0002` |
| Saldo insuficiente | `4000 0000 0000 9995` |
| 3D Secure | `4000 0025 0000 3155` |
| Pix que se aprova sozinho | nome do pagador **APRO** |
| CPF de teste | `191.000.000-00` ou qualquer CPF válido gerado |

---

## 1. Vitrine e navegação

- [ ] **Home** carrega, tudo em português, marca escrita "ocico store" em minúsculas.
- [ ] **Cabeçalho**: País ▾, Cartas Avulsas, Produtos ▾, Coleções ▾.
  - Passar o mouse abre o menu; clicar **fixa** aberto até clicar fora.
  - Coleções mostra as 7 mais recentes + "Ver todas as coleções..." → `/colecoes`.
- [ ] **Cartas Avulsas** lista só cartas avulsas.
- [ ] **Filtros da busca** (barra lateral): marque um país + um tipo → resultado é
  a interseção (nunca "nenhum produto" quando existe produto que atende aos dois).
- [ ] **Filtro de condição** (NM/LP/...) e de **preço** funcionam combinados.
- [ ] **Busca** pelo campo do cabeçalho: autocompleta e leva ao produto.
- [ ] **Página de produto**: nome, preço em R$, propriedades (raridade, número),
  seletor de condição muda preço/estoque; "Você também pode gostar" aparece.
- [ ] **Tema claro/escuro**: o botão alterna e a escolha persiste ao recarregar.
- [ ] **Celular** (DevTools → modo responsivo, 375px): menu, produto, carrinho e
  checkout sem rolagem horizontal; etapas do checkout quebram em duas linhas.
- [ ] **Rodapé** → "Termos de serviço" abre `/termos-de-servico`.

## 2. Carrinho

- [ ] Adicionar produto → contador do carrinho no cabeçalho atualiza.
- [ ] Alterar quantidade e "Atualizar" → subtotal recalcula.
- [ ] Quantidade maior que o estoque → mensagem de erro, não aceita.
- [ ] "Remover" tira o item; carrinho vazio mostra a mensagem de carrinho vazio.
- [ ] **Cupom**: crie uma promoção no admin (Promoções → nova, com código, ex.
  10% de desconto) e aplique no carrinho/checkout → desconto aparece no resumo.
  Código inválido → mensagem de erro em português.

## 3. Conta de cliente

- [ ] **Cadastro** (`/signup`) → entra logado.
- [ ] **Sair / Entrar** (`/login`), senha errada → erro em português.
- [ ] **Esqueci a senha** (`/password/recover`) → e-mail no log, em português;
  o link do e-mail permite trocar a senha.
- [ ] **Minha conta** (`/account`): editar e-mail/senha; lista de pedidos.
- [ ] Todas as mensagens (entrar, sair, conta atualizada, e-mail inválido) em português.
- [ ] "Minha conta" → pedidos com situação do pagamento e da entrega em português;
  pedido enviado com selo verde, pendente com selo amarelo.

## 4. Checkout — endereço e frete

- [ ] Checkout como **visitante** (informar e-mail) e como **logado**.
- [ ] **CEP primeiro**: digitar `01310-100` → máscara aplicada, rua/bairro/cidade/estado
  preenchidos pelo ViaCEP. Número e bairro são obrigatórios.
- [ ] CEP com formato inválido → erro de validação.
- [ ] **Entrega** com Melhor Envio (sandbox):
  - CEP de SP/RJ → aparecem PAC, SEDEX, Jadlog e Mini Envios (se o pedido for
    leve e < ~R$100), cada um com preço e "Entrega em X a Y dias úteis";
    o mais barato vem selecionado.
  - Pedido caro ou pesado (ex. booster box) → Mini Envios some.
  - CEP remoto `69900-000` → só PAC e SEDEX.
  - Trocar a opção de frete muda o total no resumo.
- [ ] **Fallback**: pare o servidor, suba-o **sem** `MELHOR_ENVIO_TOKEN`
  (abra um terminal sem carregar o `.env` do Melhor Envio) → aparece só
  "Entrega padrão R$ 20,00". Volte com o token depois (o cache de falha dura 1 min).

## 5. Checkout — pagamento

Para cada um, vá até a confirmação, **marque o aceite dos termos** (tentar sem
marcar deve mostrar o aviso "Para finalizar o pedido, leia e aceite...") e
confira na confirmação: itens + frete = total.

### Cartão (Stripe)
- [ ] `4242...` → pedido concluído; no admin o pagamento fica **pendente
  (autorizado)**, não capturado. No terminal do `stripe listen` aparecem os eventos
  com resposta 200.
- [ ] `4000 0000 0000 0002` → mensagem de recusa **em português**, pedido não conclui.
- [ ] `4000 0000 0000 9995` → mensagem de saldo insuficiente em português.
- [ ] `4000 0025 0000 3155` → janela de 3D Secure; "Complete" conclui, "Fail" recusa.

### Pix (Mercado Pago)
- [ ] Nome do pagador **APRO** → página do pedido mostra QR Code e código copia-e-cola
  (botão de copiar funciona). Aguarde alguns segundos, rode
  `bin/rails mercado_pago:sync` → pagamento **concluído**, pedido pago.
- [ ] Outro nome qualquer → fica pendente; o pedido segura o estoque.

### Boleto (Mercado Pago)
- [ ] Informar CPF → página do pedido mostra linha digitável e link do boleto.
  Pedido fica com pagamento pendente.

## 6. Pós-compra (cliente)

- [ ] E-mail de **confirmação do pedido** no log, em português (assunto
  "ocico store Confirmação do pedido #R...").
- [ ] Página do pedido acessível pelo link do e-mail (visitante) e em "Minha conta".
- [ ] Abrir o link do pedido de outro cliente numa janela anônima → **não** deve
  mostrar o pedido (redireciona/negado).

## 7. Admin (`/admin`)

### Catálogo
- [ ] Criar produto: nome, preço em R$, taxons (Origem, Tipo, Coleção),
  propriedades raridade/número, variantes por **condição**, estoque, imagem.
  Ele aparece na vitrine e nos filtros certos.
- [ ] Peso/dimensões na variante (kg/cm) → a cotação de frete muda em relação ao padrão do tipo.
- [ ] Preço de custo (`cost_price`) aceita valor em BRL (base do relatório de margem futuro).
- [ ] Locais de estoque: o local principal tem CEP 92020-300 (Canoas/RS).

### Pedidos e dinheiro
- [ ] **Capturar cartão**: pedido pago com `4242` → Pagamentos → Capturar →
  estado "concluído"; no painel da Stripe (modo teste) o pagamento aparece capturado.
- [ ] **Enviar**: Remessas → informar **código de rastreio** → Enviar → e-mail de
  envio no log com o rastreio.
- [ ] **Reembolso parcial** (cartão e Pix): Pagamentos → Reembolsar com valor menor
  que o total → reembolso aparece no admin e no painel do provedor; com o
  `stripe listen` aberto, o `charge.refunded` não duplica o reembolso.
- [ ] **Cancelar pedido** com Pix/Boleto não pago → pedido cancelado, **estoque
  volta**.
- [ ] Endereço no admin (editar cliente/pedido) tem os campos número e bairro,
  nas duas versões do admin (nova e clássica).
- [ ] Promoções: criar, ativar, aplicar cupom, conferir "primeira compra" se configurada.

## 8. Termos e textos legais

- [ ] `/termos-de-servico` e a caixa rolável na confirmação mostram o mesmo texto.
- [ ] ⚠️ Antes de publicar: preencher os campos marcados em amarelo (razão social,
  endereço, e-mail, prazo de postagem, data) e pedir revisão de um advogado.

## 9. Robustez (opcional, rápido)

- [ ] Dois navegadores comprando a **última unidade** do mesmo item ao mesmo tempo
  → só um conclui; o outro recebe aviso de estoque insuficiente.
- [ ] Clicar duas vezes rápido em "Finalizar pedido" → um pedido/um pagamento só.
- [ ] Recarregar a página de confirmação depois de pagar → não cobra de novo.
