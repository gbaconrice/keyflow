# インストール手順（Windows + 無料のApple Account）

App Storeを使わず、無料のApple Accountで署名してiPhoneに入れる手順です。
Macは不要です。ビルドはGitHub Actions（macOSの仮想マシン）で行い、Windowsでは署名とインストールだけを行います。

> 注意: この手順は公開情報をもとに書いています。2026年10月時点で、実機（iPhone）へのインストールはまだ確認していません。確認できたら、この文書の「確認状況」を更新します。

## 全体の流れ

1. GitHub Actionsが署名なしの `KeyFlow.ipa` を作る
2. Windowsの「Sideloadly」で、自分のApple Accountを使って署名し、iPhoneにインストールする
3. iPhoneで開発元を信頼し、デベロッパモードをオンにする
4. 「設定」でキーボードを追加する
5. 7日ごとに署名し直す（Sideloadlyの自動更新を使える）

## 無料アカウントでの制限（Appleの仕様）

| 項目 | 内容 | 出典 |
|---|---|---|
| 署名の有効期限 | 7日。期限が切れるとアプリが起動しなくなる（データは残る）。再署名が必要 | Apple「About your developer account」 |
| 登録できるApp ID | 7日間で10個まで。KeyFlowはアプリ本体とキーボードで2個使う | 同上 |
| 1台に入れられるアプリ | 3個まで。拡張機能も数に含まれるとする情報があり、その場合KeyFlowで2枠使う（Appleの文書には明記なし） | 同上、AltStore FAQ（非公式） |
| App Groups | 無料アカウントでも利用可能（Appleのcapability一覧で✓） | Apple「Supported capabilities (iOS)」 |
| 使えないもの | iCloud、プッシュ通知など。KeyFlowはどちらも使っていない | 同上 |

App Groupsは、アプリで変えた設定やユーザー辞書をキーボードに渡すために使います。
署名ツールがApp Groupを引き継げなかった場合でも、キーボードは動きます（「App Groupが使えない場合」を参照）。

## 事前準備（Windows）

1. **署名専用のApple Accountを作ることをおすすめします。** 署名ツールにパスワードを入力するため、普段のiCloudとは分けておくと安全です。iPhoneにサインインしているアカウントと別でも問題ありません。
2. **iTunesとiCloudを、Microsoft Store版ではなくAppleのWebサイト版で入れます。** Store版が入っている場合は先にアンインストールします（Sideloadlyの要件）。
3. **Sideloadly** を https://sideloadly.io/ から入れます。
4. iPhoneをUSBケーブルでPCにつなぎ、iPhoneの画面で「このコンピュータを信頼」を選びます。

## 0. GitHubでビルドできるようにする（最初の1回だけ）

ビルドはGitHub Actions（無料）で行います。次のどちらかで、ソースをGitHubのリポジトリに置きます。

**A. Claudeに任せる**: https://claude.ai/connect-github でGitHubアカウントを接続し、Claudeに「接続した」と伝えます。リポジトリの作成とアップロードはClaudeが行います。

**B. 自分でアップロードする**（GitHubアカウントがあれば、Claudeとの接続は不要）
1. GitHubで新しいリポジトリを作ります（名前は `keyflow` など。PublicにするとGitHub Actionsの実行時間が無制限）。
2. 受け取った `keyflow-source.zip` を展開します。
3. リポジトリの画面で「Add file」→「Upload files」を選び、展開した `keyflow` フォルダの**中身**（`App`、`Keyboard`、`Packages`、`.github` などすべて）をドラッグして「Commit changes」を押します。
   - `.github` フォルダも必ず含めてください。これがビルドの設定です。
4. 「Actions」タブを開き、ワークフローの実行を許可するボタンが出ていれば押します。数分〜20分ほどでビルドが終わります。

## 1. IPAを入手する

最新のビルドは次のURLから直接ダウンロードできます（`main`に変更が入るたびに自動で更新されます）。

- https://github.com/tanabe0422/keyflow/releases/download/latest/KeyFlow.ipa
- 更新日時や内容は https://github.com/tanabe0422/keyflow/releases/tag/latest で確認できます。

うまく取れないときは、GitHubの「Actions」→「Build」→ 最新の成功した実行 →「Artifacts」の `KeyFlow-ipa` からも入手できます（zipを展開すると `KeyFlow.ipa` が出てきます）。

バンドルIDが使えないというエラーが出たときは、「Actions」→「Build」→「Run workflow」で `bundle_id` と `app_group` を別の値（例: `jp.keyflow.ime.mine` と `group.jp.keyflow.ime.mine`）にして実行し、Artifactsから入手してください。

## 2. Sideloadlyで署名してインストールする

1. Sideloadlyを起動し、`KeyFlow.ipa` をウィンドウにドラッグします。
2. 「Apple account」に署名用のApple Accountを入力します。
3. 「iDevice」に自分のiPhoneが表示されていることを確かめます。
4. 「Start」を押します。初回はApple Accountのパスワードと、2ファクタ認証のコードを聞かれます。
5. 「Done.」と出たら完了です。

**詳細設定（Advanced options）について**
- 「Signing mode」は「Apple ID Sideload」のままにします。
- 拡張機能（PlugIns）を削除する設定は使わないでください。キーボード本体が消えます。

## 3. iPhoneで許可する

1. 「設定」→「一般」→「VPNとデバイス管理」で、署名に使ったApple Accountの「デベロッパApp」を開き、「信頼」をタップします。
2. iOS 16以降では、「設定」→「プライバシーとセキュリティ」→「デベロッパモード」をオンにします。再起動を求められるので従います（この項目は、署名したアプリを入れた後に表示されます）。

## 4. キーボードを追加する

1. KeyFlowアプリを開き、「キーボードを追加する」の手順に従います。
   - 「設定」→「KeyFlow」→「キーボード」→「KeyFlow」をオン
   - または「設定」→「一般」→「キーボード」→「キーボード」→「新しいキーボードを追加」→「KeyFlow」
2. 文字入力中に地球儀キーを長押しして「KeyFlow」を選びます。
3. フルアクセスはオフのままで使えます。クリック音・振動が欲しい場合だけオンにします。KeyFlowには通信機能がありません。

## 5. App Groupが使えているか確かめる

KeyFlowアプリの「キーボードを追加する」画面の「状態」で、「設定の共有」が「使用可能」になっていれば成功です。

「使用不可」の場合:
- キーボードは動きます。サイズや片手モードなどは、キーボードの候補バー右側にある調整ボタン（スライダーのアイコン）から変えられます。
- アプリで変えた設定とユーザー辞書はキーボードに届きません。
- 対処として、AltStore（Windows用のAltServer）で署名する方法があります。AltStoreはApp Groupを書き換えて登録する仕組みを持っています（未確認）。

## 6. 更新・再署名

- **7日ごとの再署名**: Sideloadlyの自動更新（Automatic refresh）を有効にすると、PCとiPhoneが同じWi-Fiにあるときに期限前に署名し直します。手動の場合は、同じ手順でもう一度インストールします。設定・学習データ・ユーザー辞書は残ります。
- **新しいバージョンへの更新**: 新しい `KeyFlow.ipa` を同じ手順でインストールします。バンドルIDが同じなら上書きされ、データは残ります。
- 期限が切れてもデータは消えません。再署名すれば元どおり使えます。

## うまくいかないとき

| 症状 | 対処 |
|---|---|
| 「Your maximum App ID limit has been reached」 | 7日間で登録できるApp IDの上限です。数日待つか、使っていない署名済みアプリを減らします |
| 「This app cannot be installed because its integrity could not be verified」 | 「VPNとデバイス管理」で開発元を信頼します |
| アプリが起動しない | 署名の期限切れです。もう一度インストールします |
| キーボードの一覧にKeyFlowが出ない | iPhoneを再起動してから「設定」→「一般」→「キーボード」を確認します |
| バンドルIDが使えない | GitHub Actionsの「Run workflow」で `bundle_id` を変えてビルドし直します |

## このリポジトリが扱わないもの

- Apple Accountのパスワードや署名用の証明書は、クラウド環境やリポジトリに保存しません。署名はすべて手元のWindowsで行います。
