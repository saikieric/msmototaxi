---
name: bilingual-comments
description: Coding convention for this project (msmototaxi) — write every doc comment, file-level comment, and non-trivial inline comment in BOTH English and Japanese. Applies whenever writing or editing Dart, SQL, shell script, or Markdown (SKILL.md) comments in this repo. Use whenever adding a comment, writing new code, reviewing a diff for style, or asked about comment/coding style.
---

Reference only — no commands to run.

参照専用 — 実行コマンドは無い。

## The rule / ルール

Every doc comment (`///`), file-level comment, and non-trivial inline
comment (`//`) in this codebase is written **twice, together, in the same
edit**: an English sentence or paragraph, immediately followed by its
Japanese translation on the next line(s). This is not a translation pass
done later — write both at the same time you write the comment.

このコードベースのすべてのドキュメントコメント（`///`）、ファイル冒頭
コメント、自明でないインラインコメント（`//`）は**同じ編集の中で2回、
同時に**書く: 英語の文または段落を書いたら、その直後の行に日本語訳を
続ける。これは後から行う翻訳作業ではなく、コメントを書くのと同時に
両方を書くこと。

```dart
/// English sentence explaining what this is.
/// 日本語訳。
///
/// A second English paragraph with more detail.
/// より詳しい説明の日本語訳。
```

```sql
-- English comment on why this exists.
-- なぜこれが存在するかの英語コメントの日本語訳。
```

This applies to Dart doc comments, SQL migration comments, shell script
headers/comments, and `SKILL.md` prose alike — every `.claude/skills/`
file in this project follows the same pattern (see `run-msmototaxi`,
`supabase-migrate`, `flutter-check`, `project-conventions`).

これはDartのdocコメント、SQLマイグレーションのコメント、シェルスクリプトの
ヘッダー/コメント、`SKILL.md`の本文すべてに当てはまる — このプロジェクトの
`.claude/skills/` 配下の全ファイルが同じパターンに従っている
（`run-msmototaxi`、`supabase-migrate`、`flutter-check`、
`project-conventions` 参照）。

## What stays English-only / 英語のみのままにするもの

- **Code identifiers** — class/function/variable/enum names. Bilingual
  applies to *prose*, not to code.
- **Commit messages** — see `git log` in this repo; every commit message
  so far is English-only.

- **コード識別子** — クラス名・関数名・変数名・enum値。併記の対象は
  「文章」であって「コード」ではない。
- **コミットメッセージ** — このリポジトリの `git log` 参照。これまでの
  コミットメッセージはすべて英語のみ。

## What's neither: user-facing UI strings go through i18n, not bilingual comments / どちらでもないもの: ユーザー向けUI文言はi18n経由（併記コメントの対象外）

**User-facing UI strings are localized (pt/ja) via `lib/l10n/*.arb` and
`AppLocalizations`** — see `lib/l10n/app_pt.arb` (default/template,
Brazilian Portuguese) and `lib/l10n/app_ja.arb` (Japanese). Never
hardcode a UI string directly in a widget; add a key to both `.arb`
files (pt value + ja value) and call it via
`AppLocalizations.of(context)!.yourKey`, run `flutter pub get` to
regenerate, then use it. This is a different mechanism from the
bilingual-comment convention above — an ARB key holds one language's
text per file, not an English+Japanese pair in one string — and it's
not optional the way "add a Japanese comment" is: a UI string with no
`.arb` entry simply won't render in either language properly.

**ユーザー向けUI文言は `lib/l10n/*.arb` と `AppLocalizations` 経由で
多言語化（pt/ja）する** — `lib/l10n/app_pt.arb`（デフォルト/テンプレート、
ブラジルポルトガル語）と `lib/l10n/app_ja.arb`（日本語）参照。ウィジェットに
UI文言を直接ハードコードしないこと。両方の`.arb`ファイルにキーを追加し
（pt値・ja値の両方）、`AppLocalizations.of(context)!.キー名` で呼び出し、
`flutter pub get` で再生成してから使う。これは上記の英日併記コメント規約とは
別の仕組み — ARBキーは1ファイルにつき1言語のテキストを持ち、1つの文字列に
英日ペアが入るわけではない — そして「日本語コメントも足す」ほど任意でもない:
`.arb`にエントリの無いUI文言はどちらの言語でも正しく表示されない。

## When touching old code / 古いコードを触るとき

This convention was adopted partway through the project. If you find an
older English-only (or Japanese-only) comment while already editing that
code, bring it up to the bilingual convention as part of your edit —
don't go hunting for stragglers elsewhere as a separate task unless asked.

この規約はプロジェクトの途中から採用した。既にそのコードを編集している
最中に古い英語のみ（または日本語のみ）のコメントを見つけたら、その編集の
一環として併記に揃える — 依頼されない限り、他の箇所の未対応コメントを
わざわざ別タスクとして探し回らなくてよい。
