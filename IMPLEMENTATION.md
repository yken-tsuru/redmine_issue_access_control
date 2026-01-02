# 実装詳細 (Implementation Details)

本プラグイン `redmine_issue_access_control` の技術的な実装内容および仕様について記載します。

## 1. アーキテクチャ概要
本プラグインは、Redmine 標準の `Issue` モデルおよび `visible?` メソッドを拡張（パッチ）することで、チケットごとのきめ細やかなアクセス制御を実現しています。
また、標準のフック機能を利用して UI を拡張しています。

## 2. データモデル
### IssueAccessRule (`issue_access_rules` テーブル)
チケットと、閲覧を許可されたプリンシパル（ユーザーまたはグループ）の多対多のリレーションを管理します。

- `issue_id`: チケット ID
- `principal_id`: ユーザーまたはグループの ID

## 3. ロジック拡張 (`IssuePatch`)
`lib/redmine_issue_access_control/patches/issue_patch.rb` にて、`Issue` モデルを拡張しています。

### 閲覧権限の判定 (`visible?`)
標準の `visible?` メソッドをオーバーライドし、以下の順序で判定を行います。

1. **管理者 (Admin)**: 常に閲覧可能 (`true`)
2. **標準の権限チェック**: Redmine 標準の可視性チェックで不可(`false`)なら、不可。
3. **モジュール有効判定**: プロジェクトで本モジュールが無効なら、標準通り閲覧可能 (`true`)。
4. **全閲覧権限**: ユーザーが `:view_all_restricted_issues` 権限を持っていれば閲覧可能 (`true`)。
5. **アクセスルール判定 (ホワイトリスト)**:
   - チケットの作成者 (`author`) または担当者 (`assigned_to`) は閲覧可能。
   - `IssueAccessRule` に自身の ID または所属グループ ID が含まれていれば閲覧可能。
   - **上記以外は閲覧不可 (`false`)**。 (Default Deny)

### SQL クエリの拡張 (`visible_condition`)
チケット一覧画面などで使用される SQL 条件句も同様に拡張し、データベースレベルでフィルタリングを行っています。

## 4. UI 拡張 (Hooks & Views)
`lib/redmine_issue_access_control/hooks/issues_hook_listener.rb` を通じて、以下の画面拡張を行っています。

### チケット作成・編集画面
- **フック**: `view_issues_form_details_bottom`
- **パーシャル**: `app/views/issue_access_control/_form.html.erb`
- **機能**: アクセス制御用のチェックボックスリストを表示。
  - **不具合対策**: 全チェック解除時にパラメータが送信されるよう、隠しフィールド (`hidden_field_tag`) を実装済み。

### チケット保存処理
- **フック**: `controller_issues_new_after_save`, `controller_issues_edit_after_save`
- **処理**: フォームから送信された `principal_ids` を受け取り、`IssueAccessRule` レコードを再生成（全削除＆再作成）します。

### チケット詳細画面
- **フック**: `view_issues_show_details_bottom`
- **パーシャル**: `app/views/issue_access_control/_show_access_list.html.erb`
- **機能**: 現在アクセスを許可されているメンバー（`allowed_principals`）のリストを表示。

## 5. ロールと権限の設定
### プラグイン定義の権限
- `:set_issue_access_control`: チケットのアクセス制限を設定する権限。
- `:view_all_restricted_issues`: 制限に関わらず全てのチケットを閲覧する権限（監査用など）。

### 担当者ロールの制限（Redmine設定）
本プラグインの機能ではありませんが、運用として以下のロール設定変更を行うことで、担当者の絞り込みを実現しています。

- **設定内容**: 特定のロール（管理者、Superなど）の「担当者になれる (`assignable` / `issues_visibility`)」フラグを `OFF` に設定。
- **目的**: 閲覧・管理はできるが、作業担当者としてアサインできないようにするため。
