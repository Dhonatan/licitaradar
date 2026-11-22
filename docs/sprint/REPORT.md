# Relatório final do sprint de bootstrap (17 a 22 de novembro de 2026)

**Resultado:** a Fase 1 do LicitaRadar está pronta como **v0.1.0**. O app sincroniza as
licitações abertas do PNCP a cada 6 horas, tem busca pública em português com filtros e
nichos, contas com buscas salvas e resumo diário por e-mail, API JSON v1 com tokens para o
futuro portal React, página de status, páginas de erro amigáveis e uma imagem Docker de
produção testada no CI. A `main` termina o sprint **verde** em todos os jobs.

Tudo foi verificado por testes automatizados (WebMock + fixtures fictícias) e pelo CI. O
app **ainda não rodou contra o PNCP real nem foi publicado**: esse é o primeiro passo
recomendado (issue [#7](https://github.com/Dhonatan/licitaradar/issues/7)).

---

## 1. O que foi construído, por área

### Integração com o PNCP (`lib/pncp`, Ruby puro, sem Rails)
- Cliente da API pública de consulta: endpoints de propostas abertas e de publicações,
  paginação automática, tentativas com espera exponencial em 429/5xx/erros de rede,
  HTTP 204 tratado como página vazia, corpo forçado para UTF-8.
- Normalizador: datas no horário de Brasília, decimais, CNPJ só com dígitos, link público
  do edital no PNCP; valor 0 tratado como "valor sigiloso".
- LGPD: CPFs (com dígitos verificadores válidos) mascarados em textos livres e no `raw`.
- `bin/pncp-probe` para testar a API real sem banco.

### Sincronização e dados
- Tabela `tenders` com coluna gerada `searchable` (tsvector em português, acentos
  removidos com `translate()`) e índice GIN; índices em prazo, UF, modalidade e situação.
- `Tenders::Sync`: idempotente (upsert pelo número de controle do PNCP, lotes de 200),
  uma modalidade com erro não interrompe as outras, registros inválidos são contados e
  ignorados, auditoria em `SyncRun`.
- **Dia 5:** três camadas de novas tentativas — o cliente repete cada requisição; o
  `SyncOpenTendersJob` agenda de novo só as modalidades que falharam (após 15 e mais 45
  minutos, campo `attempt` no `SyncRun`); na terceira falha reporta ao `Rails.error` e
  envia e-mail para `ADMIN_EMAIL` (`AdminMailer#sync_failed`). Execuções que ficaram
  "running" porque o processo morreu são fechadas como falha na sincronização seguinte.

### Busca e interface pública
- `Tenders::Search`: texto em sintaxe de busca web (frases, exclusões, OR), ranking por
  relevância, filtros por UF, modalidade, faixa de valor e "encerra em N dias",
  ordenação e paginação; parâmetros inválidos são ignorados.
- Nichos prontos em `config/niches.yml` (Marketing e comunicação, Eventos, TI).
- Páginas: início (busca, nichos, números), resultados (Turbo Frame), detalhe com
  contagem regressiva do prazo e links para o PNCP e o sistema de origem.
- Interface e mensagens de validação em português; 30 licitações fictícias no seed.
- **Dia 5:** páginas de erro estáticas em português (400, 404, 406 navegador não
  suportado, 422, 500). A página 406 faltava e o `allow_browser` teria gerado um erro 500
  para navegadores antigos.

### Contas, buscas salvas e alertas
- Autenticação no padrão do Rails 8 (escrita à mão): cadastro, login, logout, redefinição
  de senha, limite de tentativas (10 a cada 3 minutos por IP).
- Buscas salvas (até 20 por conta) com o botão "Salvar esta busca"; `SavedSearches::Matcher`
  encontra o que é novo desde o último alerta; `Notification` com índice único garante
  que uma licitação nunca é enviada duas vezes para a mesma busca.
- Resumo diário (HTML + texto): um e-mail por pessoa, agrupado por busca, 20 mais
  urgentes por busca, links de descadastro por busca e por conta, `List-Unsubscribe`
  de um clique.
- Solid Queue com tabelas no banco principal: sincronização às 00:30, 06:30, 12:30 e
  18:30 e resumo às 07:00 (horário de Brasília).

### API JSON v1 (`docs/API.md`)
- Tokens de API (só o hash SHA-256 é guardado, mostrado uma vez, até 10 por conta),
  `Authorization: Bearer`, limite de 300 requisições a cada 5 minutos por token, erros
  em JSON padronizados.
- `GET /api/v1/tenders` (mesmos filtros do site, `meta` com paginação e filtros
  aplicados), `GET /api/v1/tenders/:id`, `GET/POST/DELETE /api/v1/saved_searches`.

### Operação e deploy (Dia 5)
- `Dockerfile` multi-stage (Ruby 3.3.13 slim, jemalloc, usuário sem root, assets
  pré-compilados, sem Node), `bin/docker-entrypoint` (roda `db:prepare` antes do servidor;
  `SKIP_DB_PREPARE=1` desliga), `.dockerignore`.
- Job de CI "Docker image": constrói a imagem, sobe com PostgreSQL, testa `/up`, `/`,
  uma busca, o 404 e confere que o Solid Queue registrou seus processos.
- Página `/status` com autenticação básica (`STATUS_USERNAME`/`STATUS_PASSWORD`; sem elas
  a página não existe): situação de cada modalidade, falhas seguidas, números, fila de
  jobs e últimas execuções. `/status.json` responde 503 quando algo está errado, para
  monitores de uptime.
- `docs/DEPLOY.md`: variáveis de ambiente, como rodar web e jobs, checklist pós-deploy,
  Render, Fly.io, Kamal e Docker puro, backups e operação.

### Desempenho (Dia 5, `docs/PERFORMANCE.md`)
- Planos de execução medidos numa base sintética de 60 mil licitações (PostgreSQL 16):
  listagem padrão 2,4 ms, busca por palavra-chave 13 ms, nicho 17 ms — todas usam
  índices; nenhum índice novo foi necessário.
- Testes que desligam o seq scan e exigem o índice GIN nas buscas de texto e nicho e o
  índice de notificações no matcher; testes de N+1 garantindo o mesmo número de queries
  para 1 ou 25 registros na página de resultados e na API.

### Documentação
- README com funcionalidades, seção de screenshots (a preencher após o deploy),
  diagrama de arquitetura em Mermaid e instruções de deploy.
- `CHANGELOG.md` (v0.1.0), `ROADMAP.md` atualizado, `docs/DEVELOPMENT.md` (convenções e
  notas de domínio), `docs/API.md`, `docs/DEPLOY.md`, `docs/PERFORMANCE.md`.

---

## 2. Como rodar localmente

Requisitos: Ruby 3.3.13 e PostgreSQL 14+.

```bash
git clone https://github.com/Dhonatan/licitaradar.git
cd licitaradar
cp .env.example .env          # ajuste DB_HOST / DB_USERNAME / DB_PASSWORD
bin/setup                     # instala as gems e prepara o banco
bin/rails db:seed             # 30 licitações fictícias (funciona sem internet)
bin/rails server              # http://localhost:3000
```

- Dados reais: `bin/rails pncp:sync` (ou `MODALITIES=6,8 bin/rails pncp:sync`).
- Jobs e agenda recorrente: `bin/jobs`.
- Pré-visualização dos e-mails: `/rails/mailers/digest_mailer/daily` e
  `/rails/mailers/admin_mailer/sync_failed`.
- Página de status: defina `STATUS_USERNAME` e `STATUS_PASSWORD` e abra `/status`.
- Testes: `ruby bin/test-lib` (sem gems), `bin/rails test`, `bin/rubocop`, `bin/brakeman`.

## 3. Como fazer o deploy

Resumo (detalhes em [`docs/DEPLOY.md`](../DEPLOY.md)):

1. PostgreSQL 14+ gerenciado e um provedor SMTP (com SPF/DKIM no domínio do remetente).
2. Publicar a imagem do `Dockerfile` (Render "Docker", `fly deploy`, Kamal ou qualquer host
   Docker) com: `DATABASE_URL`, `SECRET_KEY_BASE`, `APP_HOST`, `MAIL_FROM`, `SMTP_*`,
   `ADMIN_EMAIL`, `STATUS_USERNAME`, `STATUS_PASSWORD` e `SOLID_QUEUE_IN_PUMA=1` (ou um
   segundo serviço rodando `./bin/jobs`). Health check: `/up`. Manter ao menos uma
   instância sempre ligada (a agenda roda dentro dela).
3. Primeira carga: `bin/rails pncp:sync` num console do servidor.
4. Conferir `/status`, criar uma conta, testar a redefinição de senha (e-mail chegando) e
   apontar um monitor de uptime para `/status.json`.

## 4. Testes e CI

| Verificação | Situação no fim do sprint |
| --- | --- |
| Testes de `lib/` (`ruby bin/test-lib`) | 38 testes, 94 asserções, 0 falhas |
| Testes Rails (PostgreSQL 16 no CI) | 292 testes, 1.331 asserções, 0 falhas (eram 252 no Dia 4) |
| RuboCop (rails-omakase, bloqueante) | verde |
| Brakeman | verde |
| Imagem Docker (build + smoke test) | verde (novo no Dia 5) |

O CI regenera e commita `Gemfile.lock` e `db/schema.rb` (como `github-actions[bot]`).
No Dia 5 houve **uma** execução vermelha (`a65859c`): dois testes novos de desempenho —
argumentos passados como palavras-chave em vez de hash e a contagem de queries afetada
pelo cache de queries entre requisições. Corrigido no commit seguinte (`6dc1611`); todas
as outras execuções do dia passaram.

## 5. O que falta ou é frágil

- **Nunca rodou contra o PNCP real neste ambiente** (pncp.gov.br bloqueado aqui): a
  integração foi validada com fixtures baseadas na documentação e no `bin/pncp-probe`.
  Tempo de sincronização, volume e registros "estranhos" só serão conhecidos no primeiro
  deploy ([#7](https://github.com/Dhonatan/licitaradar/issues/7)).
- **E-mails não são confirmados**: qualquer pessoa pode cadastrar o e-mail de outra e ela
  passará a receber resumos ([#2](https://github.com/Dhonatan/licitaradar/issues/2)).
  Resolver antes do lançamento público.
- **Sem serviço de rastreamento de erros**: `Rails.error.report` só chega aos logs; apenas
  a falha persistente da sincronização gera e-mail ([#6](https://github.com/Dhonatan/licitaradar/issues/6)).
- **Limites de requisição por contêiner**: o cache padrão é em arquivo; com mais de um
  contêiner web os limites valem por contêiner ([#5](https://github.com/Dhonatan/licitaradar/issues/5)).
- **Licitações encerradas nunca são apagadas**: a tabela cresce com o tempo
  ([#4](https://github.com/Dhonatan/licitaradar/issues/4)).
- **Tabelas do Solid Queue vêm de uma migração escrita à mão**: ao atualizar a gem,
  conferir mudanças de schema nas notas de versão.
- **Resumo diário só foi conferido por testes e preview**, não em clientes de e-mail reais.
- **Nichos** foram calibrados com dados fictícios; podem ter falsos positivos/negativos
  com dados reais.
- Contagem total de licitações abertas (página inicial) faz seq scan; com muito mais dados,
  colocar em cache por alguns minutos (`docs/PERFORMANCE.md`).
- O Dockerfile foi validado no CI (x86_64); build em ARM não foi testado.
- Sem screenshots no README até o primeiro deploy.

## 6. Riscos

| Risco | Impacto | Mitigação atual / sugerida |
| --- | --- | --- |
| Instabilidade ou mudança na API do PNCP | Dados desatualizados | Novas tentativas em 3 camadas, alerta por e-mail, `/status`; acompanhar mudanças de contrato da API |
| Resumos enviados para quem não pediu (sem confirmação de e-mail) | Reclamações, reputação do domínio de envio | Links de descadastro de um clique; implementar a confirmação (#2) |
| Falhas silenciosas em produção | Bugs sem ninguém saber | Monitor em `/status.json`; serviço de erros (#6) |
| Crescimento do banco | Custo, backups lentos | Rotina de arquivamento (#4) |
| `SECRET_KEY_BASE` trocado ou vazado | Sessões e links de e-mail quebrados ou forjáveis | Guardar no cofre do provedor; nunca trocar após o lançamento |
| Dependência de uma única pessoa e de um único servidor | Indisponibilidade | Deploy documentado e imagem reprodutível; backups diários |
| Dados pessoais em textos livres além de CPF | LGPD | CPFs já mascarados; revisar amostras reais no primeiro deploy |

## 7. Commits por dia

Commits do `github-actions[bot]` regenerando `Gemfile.lock`/`db/schema.rb` não listados.

**Dia 0 — ter, 17/11 (sessão manual)**
- `dab17f0` docs: roadmap, bootstrap sprint plan and development guide
- `6b010d3` chore: use Ruby 3.3.13 (available on GitHub runners)
- `fc26d88` fix(ci): strip --no-ensure-latest before invoking Brakeman

**Dia 1 — qua, 18/11 · Persistência e sincronização**
- `f850711` ci: make the RuboCop job blocking
- `21c2747` feat(db): create tenders table
- `57915e0` feat(db): add Portuguese full-text search column to tenders
- `14c763b` feat: add Tender model with validations and search scopes
- `6981f93` feat: add SyncRun model to audit PNCP sync passes
- `245135b` feat: add Tenders::Sync to upsert open tenders from the PNCP
- `801b844` feat: add SyncOpenTendersJob
- `ea78630` feat: add pncp:sync rake task
- `462b9a0` docs: log day 1 and tick the persistence + sync tasks

**Dia 2 — qui, 19/11 · Busca e interface pública**
- `2550aec` feat(db): fold accents in the tenders search column
- `9cb86ae` feat: add niche presets loaded from config/niches.yml
- `322d283` feat: add Tenders::Search query object
- `942e182` feat: add view helpers for BRL values, deadlines and external links
- `528fda0` feat: add public tender search and detail pages
- `dd6e186` feat: make the home page the search entry point
- `21fde17` feat: seed 30 fictional tenders so the UI works offline
- `9cc1cc7` test: cast the niche tsquery check to text to silence an unknown OID warning
- `fe2db8a` docs: log day 2 and tick the search + public UI tasks

**Dia 3 — sex, 20/11 · Contas e buscas salvas**
- `cf0717a` ci: resolve Gemfile.lock before installing gems
- `c5a52f6` feat: show validation messages in Portuguese
- `2e1676e` feat: add e-mail and password authentication
- `60a5730` fix: remember the return URL for HEAD requests too
- `c206cfb` feat: add sign-up page
- `7829ebb` feat: add SavedSearch model
- `38218f3` feat: add saved searches UI and the "Salvar esta busca" button
- `2b92d6e` fix: pass saved search criteria to Tenders::Search as a hash
- `5ee276c` feat: add Notification to record alerts already sent
- `1efd70f` feat: add SavedSearches::Matcher
- `fc15524` docs: log day 3 and tick the accounts + saved searches tasks

**Dia 4 — sáb, 21/11 · Alertas e API**
- `50506d2` feat: add the daily digest e-mail
- `f617abf` feat: add unsubscribe links to the daily digest
- `ff620b6` feat: add SendDailyDigestsJob
- `b98b7cc` feat: schedule the sync and the daily digest with Solid Queue
- `5a36717` feat: add API tokens
- `687bae5` feat: add the JSON API v1 for tenders
- `47fde9a` feat: add saved searches to the JSON API v1
- `07b66ea` chore: configure SMTP delivery and the sender address for production
- `331c13e` docs: document the JSON API v1 with curl examples
- `764a41e` docs: log day 4 and tick the alerts + API tasks

**Dia 5 — dom, 22/11 · Robustez e release**
- `839ebef` feat: retry failed sync modalities and alert the admins when they keep failing
- `8843915` feat: add friendly error pages in Portuguese
- `b39d213` test: check that searches use the indexes and pages have no N+1 queries
- `a65859c` docs: add performance notes with the search query plans
- `6dc1611` test: count cached queries in the N+1 guard and pass search params as a hash
- `352bde8` chore: add a production Dockerfile and build + smoke test it in CI
- `7e3cf04` feat: add the admin status page with the sync health per modality
- `8d3cef4` docs: add the deploy guide (Docker, Render, Fly.io, Kamal)
- `bf86524` docs: polish the README with features, screenshots section and architecture diagram
- `fa6fbe9` docs: update the roadmap and add the v0.1.0 changelog
- mais o commit deste relatório (relatório, plano, log)

## 8. Próximos passos sugeridos

Issues abertas no GitHub no Dia 5:

| # | Issue | Prioridade |
| --- | --- | --- |
| [#7](https://github.com/Dhonatan/licitaradar/issues/7) | Primeiro deploy público: configuração real, screenshots e checagem da sincronização ao vivo | 1 — fazer já |
| [#2](https://github.com/Dhonatan/licitaradar/issues/2) | Confirmar e-mail antes de enviar resumos | 1 — antes do lançamento |
| [#6](https://github.com/Dhonatan/licitaradar/issues/6) | Rastreamento de erros em produção | 2 |
| [#5](https://github.com/Dhonatan/licitaradar/issues/5) | Cache compartilhado para os limites de requisição | 2 (só ao escalar) |
| [#3](https://github.com/Dhonatan/licitaradar/issues/3) | API v1: `PATCH` de buscas salvas, listas de nichos e modalidades | 2 — pré-requisito do portal |
| [#1](https://github.com/Dhonatan/licitaradar/issues/1) | **Fase 2: portal React** sobre a API JSON | 3 |
| [#4](https://github.com/Dhonatan/licitaradar/issues/4) | Arquivar/apagar licitações encerradas há muito tempo | 3 |
| [#8](https://github.com/Dhonatan/licitaradar/issues/8) | Backlog: exportação CSV, webhooks, página pública de estatísticas, i18n | 4 |

Ordem sugerida:

1. **Deploy e validação com dados reais (#7):** publicar, rodar a primeira sincronização,
   olhar `/status`, ajustar nichos e conferir o resumo em clientes de e-mail. Criar a tag
   `v0.1.0` quando o deploy estiver de pé.
2. **Confirmação de e-mail (#2) e rastreamento de erros (#6)** antes de divulgar.
3. **Portal React — Fase 2 (#1):** decidir primeiro (a) se o portal fica na mesma origem
   (servido pelo Rails) ou em outra (exige CORS) e (b) como o navegador se autentica — os
   tokens pessoais atuais não devem ficar no `localStorage`; o ideal é um endpoint baseado
   na sessão ou tokens curtos emitidos no login. Depois completar a API (#3: `PATCH`,
   nichos, modalidades, documentos do edital via `/arquivos`) e construir com Vite +
   React + TypeScript: dashboard com prazos, busca com os mesmos filtros, detalhe com
   documentos, gestão de buscas salvas, visões compartilháveis para consultores.
4. Fase 3 (documentos dos editais, resultados e preços, análise de mercado) e Fase 4
   (planos pagos, alertas por WhatsApp/Telegram, contas de equipe), conforme o
   [`ROADMAP.md`](../../ROADMAP.md).
