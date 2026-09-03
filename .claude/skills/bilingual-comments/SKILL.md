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

## What stays Japanese-only / 日本語のみのままにするもの

- **User-facing UI strings** (button labels, screen text, error messages
  shown to the user) — this is a Japanese-market app for a Brazilian
  city (Registro, SP — see `../slides/slides.md`), and the UI text is
  Japanese throughout the codebase already. Don't add English UI strings
  or bilingual UI strings — only the *code comments explaining* the UI
  are bilingual, not the UI text itself.

- **ユーザー向けUI文言**（ボタンのラベル、画面のテキスト、ユーザーに
  表示するエラーメッセージ）— これはブラジルの都市（Registro市、SP州 —
  `../slides/slides.md` 参照）向けの日本市場アプリで、UI文言は
  コードベース全体を通して既に日本語のみ。英語のUI文言や英日併記のUI
  文言を追加しないこと — 併記するのは*UIを説明するコードコメント*であって、
  UI文言そのものではない。

## When touching old code / 古いコードを触るとき

This convention was adopted partway through the project. If you find an
older English-only (or Japanese-only) comment while already editing that
code, bring it up to the bilingual convention as part of your edit —
don't go hunting for stragglers elsewhere as a separate task unless asked.

この規約はプロジェクトの途中から採用した。既にそのコードを編集している
最中に古い英語のみ（または日本語のみ）のコメントを見つけたら、その編集の
一環として併記に揃える — 依頼されない限り、他の箇所の未対応コメントを
わざわざ別タスクとして探し回らなくてよい。
