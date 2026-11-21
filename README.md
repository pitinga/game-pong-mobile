# Pong Mobile 🏓

Pong arcade **offline**, de um jogador contra o computador, feito em **Godot 4 com GDScript**. Sem anúncios, contas, bibliotecas extras ou imagens pesadas.

## Funcionalidades

- Controle da raquete por **toque/arraste** na tela; no computador, **mouse, W/S ou setas**.
- Três dificuldades para a CPU: **Fácil, Médio e Difícil**.
- Bola acelera após cada rebatida; ângulo varia conforme o ponto de contato.
- Placar até **7 pontos** e tela de vencedor.
- **Pausa**, continuar, reiniciar e voltar ao menu.
- Efeitos visuais neon e efeitos sonoros sintetizados em tempo de execução.
- Tela horizontal (**paisagem**), otimizada para celulares Android.

## Executar

1. Instale o [Godot 4.7.2](https://godotengine.org/download/) (versão padrão, sem .NET).
2. No Godot, selecione **Importar** e escolha `project.godot`.
3. Pressione **F6/F5** para iniciar a cena/projeto.

Também é possível executar pelo terminal:

```bash
godot --path .
```

## Testes

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_pong.gd
```

## Android (APK de teste)

1. No Godot, configure **Editor → Editor Settings → Export → Android** com os caminhos do JDK e do Android SDK.
2. Instale os **Export Templates** da versão 4.7.2 pelo editor.
3. Em **Project → Export**, selecione **Android** e exporte com **Export With Debug** ativado.

Para gerar pela linha de comando, com o ambiente Android configurado:

```bash
godot --headless --path . --export-debug Android build/pong-mobile-debug.apk
```

Os commits na branch `main` executam testes e geram um **APK de teste** como artefato do GitHub Actions, desde que o workflow conclua com sucesso. O APK de debug é próprio para instalação manual e testes, **não** para publicação na Play Store. Para publicar na loja, será necessário configurar assinatura de release e gerar um AAB.

## Estrutura

```text
assets/icon.svg             Ícone vetorial do jogo
scenes/main.tscn            Cena principal
scripts/pong.gd             Interface, física, IA e sons
tests/test_pong.gd          Testes automatizados de regras
export_presets.cfg          Configuração de exportação Android
.github/workflows/          Testes e geração do APK
```

## Licença

MIT. Consulte [LICENSE](LICENSE).
