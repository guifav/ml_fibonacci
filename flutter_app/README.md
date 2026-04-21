# Fibonacci Shells — Flutter (Android)

Port em Flutter + [flame](https://flame-engine.org/) do MVP em Pygame (`../main.py`). Mesma lógica (conchas espirais, detonação manual, Fibonacci tiers), agora com:

- **Rendering totalmente procedural** via `Canvas` (espiral dourada, brilho pulsante no cluster carregado).
- **Partículas de explosão** (fragmentos + faíscas + anel de choque) proporcionais ao tier.
- **Screen shake** que escala com Fibonacci atingido.
- **Pop-ups flutuantes** de pontuação acima do grupo detonado.
- **Touch**: tap para selecionar/trocar, **long-press** para detonar cluster dourado.
- **Top 10** persistido via `shared_preferences`.

## Estrutura

```
flutter_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart              # App entry, portrait lock
│   ├── game_screen.dart       # HUD + overlays + GameWidget
│   └── engine/
│       ├── board.dart         # Grid, Piece, Fibonacci helpers
│       ├── fibonacci_game.dart # FlameGame subclass (update/render)
│       ├── shell_painter.dart # Procedural spiral shell
│       ├── particles.dart     # Fragments, sparkles, shock rings, popups
│       ├── scores.dart        # shared_preferences leaderboard
│       └── palette.dart       # Color constants
├── test/
│   └── board_test.dart        # Unit tests for board logic
└── android/                   # Gerado pelo flutter create (ver abaixo)
```

## Setup local (primeira vez)

Este diretório contém apenas `lib/`, `test/`, `pubspec.yaml`. Os diretórios `android/`, `ios/`, etc. são gerados pelo Flutter. Para configurar:

```bash
# 1) Instale o Flutter SDK (3.22+): https://docs.flutter.dev/get-started/install
flutter --version
flutter doctor

# 2) Dentro do repositório, gere os diretórios de plataforma:
cd flutter_app
flutter create --org com.fibonaccishells --project-name fibonacci_shells \
  --platforms=android,ios --overwrite .

# 3) Resolva dependências
flutter pub get

# 4) Rode em um emulador/dispositivo Android conectado
flutter run
```

> **Observação:** `flutter create --overwrite` regera `android/`, `ios/`, `pubspec.yaml`. O `--overwrite` mantém `lib/` intacto pois já existe. **Depois disso, reabra este `pubspec.yaml`** — o `flutter create` pode sobrescrever a lista de dependências. Adicione de volta:
>
> ```yaml
> dependencies:
>   flame: ^1.22.0
>   shared_preferences: ^2.2.3
> ```
>
> E rode `flutter pub get` novamente.

## Rodar testes

```bash
flutter test
```

Cobre: `fibTier`, `isFib`, `newBoard` sem runs iniciais, `findGroups`, `recomputeCharges`, `groupContaining`, rejeição de conexões diagonais.

## Build para Android

### Debug APK
```bash
flutter build apk --debug
# saída: build/app/outputs/flutter-apk/app-debug.apk
```

### Release (para distribuição / Play Store)

1. **Gere uma keystore de release** (uma vez, guarde fora do repo):
   ```bash
   keytool -genkey -v -keystore ~/fibonacci-shells.keystore \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Crie `android/key.properties`** (gitignored):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/Users/seu-usuario/fibonacci-shells.keystore
   ```
3. **Configure `android/app/build.gradle`** (ou `build.gradle.kts`):
   - Carregar `key.properties` e referenciar em `signingConfigs.release`.
   - `applicationId "com.fibonaccishells.app"`.
   - `minSdkVersion 21`, `targetSdkVersion 34` (ou superior).
   - Versão e nome em `defaultConfig { versionCode 1; versionName "0.1.0" }`.
4. **Gere o bundle assinado** (Play Store aceita apenas AAB):
   ```bash
   flutter build appbundle --release
   # saída: build/app/outputs/bundle/release/app-release.aab
   ```

## Play Store — checklist

Parte técnica coberta pelo projeto:
- [x] Package name único (`com.fibonaccishells.app`).
- [x] `versionCode` / `versionName` em `pubspec.yaml` e propagados ao gradle.
- [x] Portrait lock; edge-to-edge.
- [ ] Ícone adaptativo (512×512 PNG + camadas foreground/background). Gerar com `flutter_launcher_icons` ou à mão.
- [ ] Screenshots (phone 1080×1920 e tablet 1200×1920, pelo menos 2).
- [ ] Feature graphic 1024×500.
- [ ] Descrição curta (80 chars) e longa (até 4000).

Parte sua (Play Console):
1. Conta Google Play Developer (taxa única $25).
2. Criar o app no console → ficha da loja (descrição, categorias, tags).
3. **Classificação de conteúdo** (IARC questionário — jogo simples de encaixar, zero violência/dados pessoais coletados → rating livre).
4. **Política de privacidade** — para um jogo sem coleta de dados, uma URL simples basta. Sugestão de texto abaixo.
5. **Data Safety** → responder "não coleta dados" (apenas salva scores localmente via SharedPreferences).
6. **Testing → Internal Testing** → subir AAB assinado → adicionar seu próprio e-mail como tester → validar.
7. Release para produção.

### Privacy policy mínima (host em qualquer página estática)

```
Fibonacci Shells — Política de Privacidade

Este aplicativo não coleta, armazena ou transmite nenhum dado pessoal.
Pontuações são salvas apenas no armazenamento local do seu dispositivo
e podem ser removidas a qualquer momento desinstalando o aplicativo.
Não há anúncios nem comunicação com servidores externos.

Contato: seu-email@exemplo.com
```

## Controles

- **Tap** em uma peça: selecionar.
- **Tap** em peça adjacente: trocar (só confirma se formar match).
- **Long-press** em peça dourada pulsante: detonar o cluster.
- **Botão "NOVA PARTIDA"** na tela de fim de jogo.
