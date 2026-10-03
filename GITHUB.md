# Publicar no GitHub

Este projeto já está pronto para versionamento. Siga os passos abaixo **uma vez**.

## 1. Conta e ferramenta

1. Crie uma conta em [github.com](https://github.com) se ainda não tiver.
2. Instale o GitHub CLI (Ubuntu):

```bash
sudo apt update
sudo apt install -y gh git
gh auth login
```

Escolha GitHub.com → HTTPS ou SSH → faça login no navegador.

## 2. Criar o repositório e enviar

Na pasta do projeto:

```bash
cd ~/Documentos/musica   # ou o caminho onde está o projeto

# Se ainda não houver commit:
git init -b main
git add -A
git status   # confira: NÃO deve aparecer .venv
git commit -m "Versão inicial do Estúdio de Áudio Bluetooth"

# Cria o repo no GitHub e envia (público):
gh repo create estudio-audio-bluetooth --public --source=. --remote=origin --push
```

Repositório privado:

```bash
gh repo create estudio-audio-bluetooth --private --source=. --remote=origin --push
```

## 3. Depois do primeiro push

No README, troque `SEU_USUARIO` pela sua URL real, por exemplo:

`https://github.com/weslley-felipe/estudio-audio-bluetooth.git`

## 4. Atualizações futuras

```bash
git add -A
git commit -m "Descreva a melhoria"
git push
```

## 5. Outras pessoas instalarem

```bash
git clone https://github.com/SEU_USUARIO/estudio-audio-bluetooth.git
cd estudio-audio-bluetooth
bash instalar-ubuntu.sh -y
```

Ou baixem o **ZIP** do GitHub (Code → Download ZIP) e usem `Instalar-no-Ubuntu.desktop`.
