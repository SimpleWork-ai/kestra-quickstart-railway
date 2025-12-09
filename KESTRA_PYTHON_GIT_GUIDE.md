# Estrutura de Flows, Python e Git no Kestra Quickstart

## Objetivos

- Ter instâncias de Kestra (local e Railway) usando **Git como fonte de verdade** para os flows.
- Orquestrar scripts Python com:
  - código reutilizável em “plugins”;
  - scripts de tasks finos que usam esses plugins;
  - testes unitários para o que importa.
- Manter a estrutura **simples (KISS)** e sem features desnecessárias (**YAGNI**).

---

## Visão geral de diretórios

Estrutura proposta na raiz do repositório:

```text
/
  _flows/
    admin/
      git-sync-flows.yaml      # flow de sistema que sincroniza flows a partir do Git
    app/
      my_first_flow.yaml       # flows de negócio
      another_flow.yaml
      ...

  python/
    plugins/
      __init__.py
      db.py                    # helpers de Postgres (conexão/leitura/escrita)
      storage.py               # outros helpers reutilizáveis
      ...
    tasks/
      __init__.py
      my_task.py               # scripts que o Kestra chama (python -m tasks.my_task)
      another_task.py
      ...
    tests/
      conftest.py
      plugins/
        test_db.py
      tasks/
        test_my_task.py
      ...

  requirements.txt             # dependências Python
  Dockerfile                   # imagem do Kestra adaptada para Railway
  application.yaml             # config do Kestra (DB, URL, Gemini, etc.)
  ...
```

- `_flows/`: apenas flows (YAML) que o Kestra vai sincronizar a partir do Git.
- `python/`: apenas código Python (plugins, tasks e testes).
- Demais arquivos: infra (Docker, config, etc.).

---

## Flows e namespaces

### `_flows/admin/git-sync-flows.yaml`

- Flow “de sistema”, no namespace `admin.git`.
- Responsável por chamar o plugin `io.kestra.plugin.git.SyncFlows` e sincronizar flows de um repositório Git para o Kestra.
- É o mesmo flow em todas as instâncias (local e Railway); o comportamento muda via variáveis de ambiente.

### `_flows/app/*.yaml`

- Flows “de negócio” (os que rodam tasks Python, pipelines de dados, etc.).
- Não há separação física de dev/prod em diretórios: **os mesmos arquivos** são usados em todos os ambientes.
- A diferença de comportamento entre dev/prod vem de:
  - namespace de destino (configurado no SyncFlows);
  - variáveis de ambiente (credenciais, URLs, etc.);
  - instância do Kestra (local vs Railway).

---

## Flow de Git Sync (conceito)

O flow `admin.git.git_sync_flows` usa o plugin `io.kestra.plugin.git.SyncFlows` com parâmetros dirigidos por variáveis de ambiente.

Principais variáveis:

- `GIT_SYNC_URL`  
  - URL do repositório Git (HTTPS ou SSH) que contém `_flows/`.  
  - Ex.: `https://github.com/sua-org/seu-repo-flows.git`.

- `GIT_SYNC_BRANCH`  
  - Branch que será sincronado.  
  - Exemplos:
    - Local: `dev` ou um branch de feature.
    - Produção (Railway): `main`.
  - Default sugerido no flow: `main`.

- `GIT_SYNC_TARGET_NAMESPACE`  
  - Namespace de destino dos flows.  
  - Exemplos:
    - Local: `dev` ou `app.dev`.
    - Produção: `app` ou `prod`.
  - Permite ter **um único conjunto de arquivos `_flows/app/*.yaml`**, carregado em namespaces diferentes conforme o ambiente.

- `GIT_SYNC_DIRECTORY`  
  - Diretório dentro do repositório onde estão os flows.
  - Padrão usado: `_flows`.

Flags importantes do `SyncFlows`:

- `includeChildNamespaces: true`  
  - Exemplo com `targetNamespace = app`:
    - `_flows/app` → namespace `app`;
    - `_flows/app/marketing` → namespace `app.marketing`;
    - `_flows/app/marketing/crm` → namespace `app.marketing.crm`.

- `ignoreInvalidFlows: true`  
  - Flows inválidos são ignorados, não quebram o sync inteiro.

### Autenticação

Configurada via env vars; escolha apenas uma estratégia por ambiente:

- HTTPS + Personal Access Token (PAT):
  - `GIT_SYNC_USERNAME`
  - `GIT_SYNC_PASSWORD` (PAT)

- SSH:
  - `GIT_SYNC_SSH_KEY` (chave privada em PEM)
  - `GIT_SYNC_KNOWN_HOSTS` (opcional)

---

## Python – plugins, tasks e testes

### `python/plugins/`

- Código reutilizável, idealmente independente do Kestra:
  - Ex.: `db.py` com helpers para conectar no Postgres, ler/escrever dados.
  - Ex.: `storage.py` para interagir com armazenamento de arquivos, etc.
- Regras:
  - Não acoplar a lógica a um flow específico.
  - Evitar dependência direta da API do Kestra.
  - Focar em funções/módulos fáceis de testar isoladamente.

### `python/tasks/`

- “Casca” fina que o Kestra chama.
- Cada arquivo implementa a lógica de um job, reutilizando plugins.
- Convenção de execução:
  - `python -m tasks.my_task`
  - `tasks` é um pacote (`__init__.py` presente).
  - Imports internos do tipo: `from plugins.db import get_connection`.

### `python/tests/`

- Estrutura espelhando `plugins/` e `tasks/`:
  - `tests/plugins/test_db.py` testa `plugins/db.py`.
  - `tests/tasks/test_my_task.py` testa `tasks/my_task.py`.
- Framework sugerido: `pytest`.
- Objetivo: garantir que mudanças em plugins e tasks sejam detectadas antes de chegar ao branch principal usado pela produção.

---

## Diferenciando dev e prod sem duplicar flows

### Instância local (dev)

- Usa a mesma base de código e os mesmos arquivos `_flows/`.
- Configurar env vars do flow `git_sync_flows` com, por exemplo:
  - `GIT_SYNC_URL` → repositório remoto (GitHub) ou esse próprio repo acessível via HTTP/SSH.
  - `GIT_SYNC_BRANCH=dev` (ou outro branch de desenvolvimento).
  - `GIT_SYNC_TARGET_NAMESPACE=dev` (ou `app.dev`).

Fluxo típico:

- Trabalhar em branches de desenvolvimento.
- Rodar o flow de sync localmente.
- Ver os flows carregados em namespaces de dev para testes.

### Instância Railway (prod)

- Usa a mesma imagem Docker (que inclui o diretório `python/` no container).
- Flows sincronizados do mesmo repo, com env vars específicas de produção:
  - `GIT_SYNC_URL` → mesmo repositório.
  - `GIT_SYNC_BRANCH=main`.
  - `GIT_SYNC_TARGET_NAMESPACE=app` (ou `prod`).

Recomendado:

- Usar CI (GitHub Actions ou similar) para:
  - rodar testes Python (plugins/tasks),
  - opcionalmente validar flows,
  - só então permitir merge para `main`.

---

## Convenções (KISS e YAGNI)

- **KISS**
  - Um único repositório para:
    - infra (Docker, configs),
    - flows (`_flows/`),
    - código Python (`python/`).
  - Sem duplicar diretórios de `dev` e `prod` para flows.
  - Uma única forma de executar tasks Python: `python -m tasks.<nome>`.

- **YAGNI**
  - Não introduzir:
    - múltiplos repositórios,
    - estrutura complexa de packages Python,
    - ou florestas de namespaces, enquanto não houver necessidade real.
  - Começar apenas com:
    - alguns plugins (`db.py`, etc.),
    - alguns tasks simples (`my_task.py`),
    - testes unitários básicos.

---

## Resumo

- `_flows/` + `admin.git.git_sync_flows` implementam o padrão **Git como fonte de verdade** para os flows em todas as instâncias de Kestra.
- `python/plugins` e `python/tasks` separam **reuso** (plugins) de **entrypoints de execução** (tasks).
- Testes vivem em `python/tests`, espelhando a estrutura de código.
- A diferença entre dev e prod é feita por **configuração** (namespace, branch, env vars), não por duplicação de arquivos ou diretórios.

