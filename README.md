# Ruffle ARM64 para TrimUI — construtor automático

Este projeto usa um **runner ARM64 nativo do GitHub Actions** e compila o
Ruffle dentro de um contêiner **Debian Bullseye ARM64 (glibc 2.31)**.

O TrimUI informou `CFW_GLIBC=233`, isto é, glibc 2.33. Um binário criado
contra 2.31 tem chance de ser compatível; as builds oficiais recentes que
testamos exigiam glibc 2.39.

## Passo a passo

1. Crie uma conta no GitHub ou entre na sua conta.
2. Clique em **New repository**.
3. Dê um nome, por exemplo: `ruffle-trimui-builder`.
4. Pode deixar o repositório **público ou privado**.
5. Crie o repositório sem adicionar README, licença ou `.gitignore`.
6. Extraia este ZIP no seu computador.
7. Na página do repositório, clique em **uploading an existing file**.
8. Arraste **todo o conteúdo extraído**, incluindo a pasta `.github`.
   - No Windows, a pasta `.github` pode parecer oculta.
   - Confirme que o arquivo aparece no GitHub como:
     `.github/workflows/build-ruffle.yml`
9. Clique em **Commit changes**.
10. Abra a aba **Actions**.
11. Na lateral, selecione **Build Ruffle for TrimUI**.
12. Clique em **Run workflow**.
13. Mantenha:
    `nightly-2024-09-26`
14. Clique novamente em **Run workflow**.

A compilação pode levar de 30 minutos a mais de 1 hora. Não feche nem
cancele o processo; a execução continua nos servidores do GitHub.

## Quando terminar

1. Abra a execução concluída na aba **Actions**.
2. Desça até **Artifacts**.
3. Baixe:
   `ruffle-trimui-aarch64`
4. O GitHub entregará um ZIP.
5. Envie esse ZIP completo ao ChatGPT.

O artefato contém o executável, bibliotecas auxiliares e relatórios de
compatibilidade. Com ele será criado o Teste 3 para Dino Run e Dad 'n Me.

## Se a compilação falhar

Abra a execução, clique no passo vermelho e copie o log. Envie o log ao
ChatGPT. O workflow foi feito para ser iterado; uma falha de dependência
não significa que o projeto acabou.
