# AlterBrain: instalador para Mac

Script de entrada do AlterBrain. Ele não tem segredo nenhum: traz o Python 3.12 e o GitHub CLI para a pasta do usuário, sem pedir senha de administrador, faz o login no GitHub pelo navegador, baixa a versão pronta mais nova do AlterBrain e começa o setup.

O AlterBrain é privado: a conta do GitHub usada no login precisa ter acesso liberado.

## Como instalar

No Terminal do Mac:

```bash
curl -fsSL -o instalar.sh https://raw.githubusercontent.com/Alter-mkt/alterbrain-instalar/main/instalar.sh
bash instalar.sh
```

A pasta de instalação é `~/AlterBrain`. Rodar o script de novo numa pasta já instalada não apaga nada: ele só chama o setup outra vez. Atualizar o AlterBrain é pelo start, dentro da IA.

Este arquivo é cópia do `instalador/instalar.sh` do repositório do AlterBrain, que é a fonte.
