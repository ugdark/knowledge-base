---
title: "ScalaからGoへの実装変換ガイド"
category: "go-lang"
tags: [Go, Scala, 言語移行, 実装パターン, リファレンス]
created: 2026-03-19
updated: 2026-03-19
---

# ScalaからGoへの実装変換ガイド

## 概要

Scala 2経験者がGoに移行する際の概念マッピングと実装パターンの対応表。Scala 2の機能がGoではどう表現されるかを整理し、移行時の判断を助ける。

---

## 0. Goの設計哲学（Scalaとの根本的な違い）

Scala→Go移行で最も重要なのは個々の構文変換ではなく、**言語の文化・哲学の違い**を理解すること。Goは意図的にシンプルさを選択しており、Scalaのやり方をそのまま持ち込むとGoらしくないコードになる。

### 「型を定義するな」

Scalaでは型を積極的に定義してコンパイラに意図を伝えるのが良い設計とされるが、Goでは**必要になるまで型を作らない**のが文化。

```scala
// Scala: 型で意図を表現する文化
type UserId = String
type Email = String
case class User(id: UserId, email: Email)

// 専用コレクション型まで定義することもある
case class Users(values: Seq[User]) {
  def activeOnly: Users = Users(values.filter(_.isActive))
}
```

```go
// Go: プリミティブをそのまま使う文化
type User struct {
    ID    string
    Email string
}

// []User をそのまま使う。ラッパー型は作らない
func ActiveOnly(users []User) []User {
    var result []User
    for _, u := range users {
        if u.IsActive {
            result = append(result, u)
        }
    }
    return result
}
```

型エイリアスを定義するのは、**メソッドを生やす必要がある場合**か、**型安全性が本当に必要な場合**のみ。

### 「interfaceは消費側が定義する」

Scala/Javaの世界では実装側が `extends`/`implements` するが、Goのinterfaceは**使う側が必要なメソッドだけ定義する**。

```scala
// Scala: 実装側がtraitを宣言
trait UserRepository {
  def find(id: String): Option[User]
  def save(user: User): Unit
  def delete(id: String): Unit
  def findByEmail(email: String): Option[User]
  def count(): Long
}

class UserService(repo: UserRepository) { ... }
```

```go
// Go: 消費側が「自分が使うものだけ」定義する
// user_service.go（使う側）
type UserFinder interface {
    Find(id string) (*User, error)
}

type UserSaver interface {
    Save(user *User) error
}

type UserService struct {
    finder UserFinder
    saver  UserSaver
}

// 実装側は何も宣言しない — メソッドがあれば自動的に満たす
```

> **"Accept interfaces, return structs"**（interfaceを受け取り、structを返せ）がGoの格言。

### 「小さいinterfaceが正義」

Go標準ライブラリのinterfaceは驚くほど小さい：

| interface | メソッド数 | 用途 |
|-----------|-----------|------|
| `io.Reader` | 1 (`Read`) | あらゆる読み取り |
| `io.Writer` | 1 (`Write`) | あらゆる書き込み |
| `fmt.Stringer` | 1 (`String`) | 文字列表現 |
| `error` | 1 (`Error`) | エラー |
| `sort.Interface` | 3 | ソート |
| `http.Handler` | 1 (`ServeHTTP`) | HTTPハンドリング |

Scalaの大きなtraitに慣れていると違和感があるが、**1-3メソッドのinterfaceを組み合わせる**のがGo流。

### 「早すぎる抽象化を避ける」

| Scalaの習慣 | Goではこうする |
|------------|--------------|
| まずtraitを定義する | まず具体的なstructを書く。interfaceは後から必要になったら |
| 汎用ユーティリティを作る | 3回同じコードを書くまでは抽象化しない |
| 型パラメータで汎用化 | 具体型で書く。Genericsは本当に必要な場合のみ |
| 暗黙の変換で楽にする | 多少冗長でも明示的に書く |
| DSLを作る | 標準的な書き方で愚直に書く |

### 「コピペは悪ではない」

Scalaでは DRY（Don't Repeat Yourself）が強く意識されるが、Goでは**少しの重複は明示性のためのコスト**として許容される。Rob Pike（Go共同設計者）の言葉：

> "A little copying is better than a little dependency."
> （少しのコピーは少しの依存より良い）

### 「エラーは値」

Scalaの例外ベース/モナドベースのエラーハンドリングと最も異なる点。Goではエラーは普通の値として扱う。

```go
// この冗長さはGoの意図的な設計判断
// 各エラーチェックポイントで「何が起きたか」が一目でわかる
user, err := repo.Find(id)
if err != nil {
    return nil, fmt.Errorf("find user %s: %w", id, err)
}

profile, err := profileSvc.Get(user.ProfileID)
if err != nil {
    return nil, fmt.Errorf("get profile for user %s: %w", id, err)
}
```

`if err != nil` の繰り返しは冗長に見えるが、**エラーパスが常に明示的**であることがGoの設計哲学。

### Scalaエンジニアが陥りがちなアンチパターン

| やりがちなこと | なぜダメか | Goではこうする |
|-------------|---------|------------|
| 全部にinterface定義 | 不要な抽象化 | 具体structから始める |
| Genericsの多用 | 可読性が下がる | 具体型で書く |
| `map`/`filter`ユーティリティ大量作成 | forループで十分 | 素朴にforループ |
| エラーを握りつぶして`panic` | Goでpanicは致命的 | `if err != nil` を書く |
| 深いパッケージ階層 | Goはフラットが好き | 浅く保つ |
| コンストラクタで全部DI | 過剰設計になりがち | 必要な依存だけ渡す |
| `Option[T]`相当を自作 | Goの慣習に反する | ポインタ/ゼロ値/errorを使う |

## 1. 型システム

| Scala | Go | 備考 |
|-------|-----|------|
| `val x: Int = 1` | `x := 1` / `var x int = 1` | Goは `:=` で型推論 |
| `var x: Int = 1` | `var x int = 1` | |
| `lazy val` | `sync.Once` + クロージャ | Goにlazy評価はない |
| `type Alias = String` | `type Alias = string` | Go 1.9+ で型エイリアス対応 |
| `type NewType extends AnyVal` | `type NewType string` | Goの型定義は新しい型を作る |
| `Any` / `AnyRef` | `any` (`interface{}`) | Go 1.18+ で `any` が使える |
| `Nothing` | なし | Goに底型はない |
| `Option[T]` | `*T` / ゼロ値 / `(T, bool)` | 後述 |
| `Either[L, R]` | `(T, error)` | Goのエラーハンドリング |
| `Tuple2[A, B]` | 多値返却 `(A, B)` | Goにタプル型はないが多値返却がある |

## 2. コレクション操作

### Scalaの関数型操作 → Goの対応

| Scala | Go | 備考 |
|-------|-----|------|
| `list.map(f)` | `for` ループ / `slices.Map`(自作) | Go 1.21+ で `slices` パッケージあるが map はない |
| `list.filter(f)` | `for` + `if` / `slices.DeleteFunc`の逆 | |
| `list.flatMap(f)` | ネストした `for` ループ | |
| `list.foldLeft(z)(f)` | `for` ループで accumulator | |
| `list.reduce(f)` | `for` ループ | |
| `list.foreach(f)` | `for _, v := range list` | |
| `list.groupBy(f)` | `map[K][]V` を手動構築 | |
| `list.sortBy(f)` | `slices.SortFunc(list, cmp)` | Go 1.21+ |
| `list.exists(f)` | `slices.ContainsFunc` | Go 1.21+ |
| `list.forall(f)` | `for` + 早期 `return false` | |
| `list.distinct` | `map` でユニーク化 | |
| `list.zip(other)` | `for i := range` で同時イテレーション | |
| `list.take(n)` | `list[:n]` | スライス構文 |
| `list.drop(n)` | `list[n:]` | スライス構文 |

### Genericsを使った汎用関数（Go 1.18+）

```go
func Map[T, U any](s []T, f func(T) U) []U {
    result := make([]U, len(s))
    for i, v := range s {
        result[i] = f(v)
    }
    return result
}

func Filter[T any](s []T, f func(T) bool) []T {
    var result []T
    for _, v := range s {
        if f(v) {
            result = append(result, v)
        }
    }
    return result
}
```

## 3. エラーハンドリング

| Scala | Go | 備考 |
|-------|-----|------|
| `Try[T]` | `(T, error)` | 多値返却が基本 |
| `Success(v)` / `Failure(e)` | `return v, nil` / `return zero, err` | |
| `try-catch` | `if err != nil` | Goに例外はない |
| `throw new Exception` | `return fmt.Errorf(...)` | panicは最終手段 |
| `recover` | `recover()` in `defer` | panicからの回復 |
| `Try { ... }.getOrElse(default)` | `v, err := f(); if err != nil { v = default }` | |
| `Either[L, R]` | `(T, error)` | |
| カスタム例外クラス | `errors.New` / カスタムerror型 | |

### エラーラッピング

```go
// Scala: throw new ServiceException("user not found", cause)
// Go:
import "fmt"

func getUser(id string) (*User, error) {
    user, err := repo.Find(id)
    if err != nil {
        return nil, fmt.Errorf("getUser(%s): %w", id, err) // %w でラップ
    }
    return user, nil
}
```

### カスタムエラー型

```go
// Scala: case class NotFoundError(entity: String, id: String) extends Exception
// Go:
type NotFoundError struct {
    Entity string
    ID     string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s not found: %s", e.Entity, e.ID)
}

// 使用側: errors.As(err, &target) で型判定
```

## 4. 並行処理

| Scala | Go | 備考 |
|-------|-----|------|
| `Future[T]` | goroutine + channel | |
| `Future.sequence` | `sync.WaitGroup` / `errgroup.Group` | |
| `Await.result` | `<-ch` / `wg.Wait()` | |
| `ExecutionContext` | Goランタイム（設定不要） | GOMAXPROCS で並列度調整 |
| `Promise[T]` | `chan T` (バッファ1) | |
| `Future.map/flatMap` | goroutine チェイン | |
| `Actor` (Akka) | goroutine + channel | CSPモデル |
| `parallel collection` | goroutine + `errgroup` | |

### Future → goroutine + channel

```go
// Scala:
// val f = Future { heavyComputation() }
// val result = Await.result(f, 10.seconds)

// Go:
ch := make(chan Result, 1)
go func() {
    ch <- heavyComputation()
}()
result := <-ch
```

### Future.sequence → errgroup

```go
// Scala:
// val futures = ids.map(id => Future { fetch(id) })
// val results = Future.sequence(futures)

// Go:
import "golang.org/x/sync/errgroup"

g, ctx := errgroup.WithContext(ctx)
results := make([]*Data, len(ids))

for i, id := range ids {
    g.Go(func() error {
        data, err := fetch(ctx, id)
        if err != nil {
            return err
        }
        results[i] = data
        return nil
    })
}
if err := g.Wait(); err != nil {
    return nil, err
}
```

## 5. パターンマッチ

| Scala | Go | 備考 |
|-------|-----|------|
| `match { case ... }` | `switch` | |
| ガード付き `case x if x > 0 =>` | `switch { case x > 0: }` | 式なしswitch |
| 型パターン `case s: String =>` | `switch v := x.(type)` | 型switch |
| `sealed trait` + exhaustive match | `interface` + 型switch | 網羅性チェックはない |
| `unapply` / Extractor | なし | 手動で分解 |
| `case class` の分解 | 構造体フィールドに直接アクセス | |

```go
// Scala:
// animal match {
//   case Dog(name) => s"Dog: $name"
//   case Cat(name) => s"Cat: $name"
// }

// Go:
switch a := animal.(type) {
case *Dog:
    fmt.Printf("Dog: %s\n", a.Name)
case *Cat:
    fmt.Printf("Cat: %s\n", a.Name)
default:
    fmt.Println("Unknown")
}
```

## 6. OOP / 型の設計

| Scala | Go | 備考 |
|-------|-----|------|
| `class` | `struct` | |
| `trait` | `interface` | 暗黙的実装（implements不要） |
| `abstract class` | `interface` + デフォルト実装用struct | 埋め込みで実現 |
| `case class` | `struct`（手動で `String()` 等を実装） | |
| `object`（シングルトン） | パッケージレベル変数/関数 | |
| `companion object` | なし（パッケージ関数で代替） | |
| `extends` / `with` | 構造体埋め込み（embedding） | 継承ではなく合成 |
| `sealed trait` | interface + 同一パッケージ内の実装 | コンパイル時の網羅性チェックなし |
| `implicit class`（拡張メソッド） | なし | 型定義 + メソッドで部分的に代替 |
| `apply()` / ファクトリ | `NewXxx()` コンストラクタ関数 | Goの慣習 |
| `private` / `protected` | 小文字始まり = パッケージプライベート | Goにprotectedはない |
| `public` | 大文字始まり = エクスポート | |

### trait → interface

```go
// Scala:
// trait Repository {
//   def find(id: String): Option[User]
//   def save(user: User): Unit
// }

// Go:
type Repository interface {
    Find(id string) (*User, error)
    Save(user *User) error
}
```

### case class → struct

```go
// Scala:
// case class User(id: String, name: String, age: Int)

// Go:
type User struct {
    ID   string `json:"id"`
    Name string `json:"name"`
    Age  int    `json:"age"`
}
```

## 7. trait 詳細（Scala 2固有）

Scala 2のtraitはGoのinterfaceよりはるかに多機能。変換時は機能ごとに分解して考える。

### 抽象メソッド付きtrait → interface

```scala
// Scala 2
trait Logger {
  def log(msg: String): Unit
}
```

```go
// Go
type Logger interface {
    Log(msg string)
}
```

### デフォルト実装付きtrait → interface + 構造体埋め込み

```scala
// Scala 2
trait Logger {
  def log(msg: String): Unit = println(s"[LOG] $msg")
  def warn(msg: String): Unit = println(s"[WARN] $msg")
}

class Service extends Logger  // そのまま使える
```

```go
// Go: デフォルト実装を持つ構造体を用意し、埋め込みで合成
type Logger interface {
    Log(msg string)
    Warn(msg string)
}

type DefaultLogger struct{}

func (l DefaultLogger) Log(msg string)  { fmt.Printf("[LOG] %s\n", msg) }
func (l DefaultLogger) Warn(msg string) { fmt.Printf("[WARN] %s\n", msg) }

type Service struct {
    DefaultLogger // 埋め込み → Log(), Warn() がServiceのメソッドになる
}
```

### 複数trait のミックスイン → 多重埋め込み

```scala
// Scala 2
trait HasID { val id: String }
trait HasTimestamp { val createdAt: Instant }
trait Auditable extends HasID with HasTimestamp {
  def auditLog: String = s"$id at $createdAt"
}
```

```go
// Go: 複数structを埋め込んで合成
type HasID struct {
    ID string
}

type HasTimestamp struct {
    CreatedAt time.Time
}

type Auditable struct {
    HasID
    HasTimestamp
}

func (a Auditable) AuditLog() string {
    return fmt.Sprintf("%s at %s", a.ID, a.CreatedAt)
}
```

### Stackable Trait Pattern → Middleware パターン

```scala
// Scala 2: Stackable Trait
trait Logging extends Repository {
  abstract override def save(user: User): Unit = {
    println(s"Saving: $user")
    super.save(user)
  }
}
class LoggingRepo extends ConcreteRepo with Logging
```

```go
// Go: Decorator / Middleware パターン
type LoggingRepository struct {
    inner Repository
}

func (r *LoggingRepository) Save(user *User) error {
    fmt.Printf("Saving: %+v\n", user)
    return r.inner.Save(user)
}

// 使用: repo := &LoggingRepository{inner: &ConcreteRepo{}}
```

### self type annotation → コンストラクタ制約

```scala
// Scala 2
trait UserComponent {
  self: DatabaseComponent =>  // DatabaseComponentが必要
  def findUser(id: String) = db.query(...)
}
```

```go
// Go: コンストラクタで依存を強制
type UserComponent struct {
    db *DatabaseComponent // 明示的に依存を持つ
}

func NewUserComponent(db *DatabaseComponent) *UserComponent {
    return &UserComponent{db: db}
}
```

## 8. implicit 詳細（Scala 2固有）

Scala 2のimplicitはGoに直接対応するものがない。用途ごとに変換戦略が異なる。

### implicit parameter → 明示的引数 / context.Context

```scala
// Scala 2
def execute(query: String)(implicit ec: ExecutionContext, timeout: Timeout): Future[Result]

// 呼び出し側
implicit val ec = ExecutionContext.global
implicit val timeout = Timeout(10.seconds)
execute("SELECT ...")  // implicitで自動解決
```

```go
// Go: 全部明示的に渡す
func Execute(ctx context.Context, query string, timeout time.Duration) (*Result, error) {
    ctx, cancel := context.WithTimeout(ctx, timeout)
    defer cancel()
    // ...
}

// 呼び出し側
Execute(ctx, "SELECT ...", 10*time.Second)
```

### implicit conversion → 明示的な変換関数

```scala
// Scala 2
implicit def intToString(i: Int): String = i.toString
val s: String = 42  // 自動変換
```

```go
// Go: 明示的にキャストまたは変換関数を呼ぶ
s := strconv.Itoa(42)
// Goに暗黙の変換は存在しない。常に明示的。
```

### implicit class（拡張メソッド）→ 型定義 + メソッド or 関数

```scala
// Scala 2
implicit class RichString(s: String) {
  def toSlug: String = s.toLowerCase.replaceAll("\\s+", "-")
}
"Hello World".toSlug  // "hello-world"
```

```go
// Go パターン1: 型定義
type Slug string

func (s Slug) ToSlug() string {
    return strings.ToLower(strings.ReplaceAll(string(s), " ", "-"))
}
// 使用: Slug("Hello World").ToSlug()

// Go パターン2: ただの関数（こちらが一般的）
func ToSlug(s string) string {
    return strings.ToLower(strings.ReplaceAll(s, " ", "-"))
}
// 使用: ToSlug("Hello World")
```

### 型クラスパターン（implicit val + implicit parameter）→ interface

```scala
// Scala 2: 型クラス
trait JsonEncoder[T] {
  def encode(value: T): String
}

implicit val userEncoder: JsonEncoder[User] = new JsonEncoder[User] {
  def encode(user: User) = s"""{"name":"${user.name}"}"""
}

def toJson[T](value: T)(implicit encoder: JsonEncoder[T]): String =
  encoder.encode(value)

toJson(user)  // implicitで自動解決
```

```go
// Go: interface を実装させる（最もシンプル）
type JsonEncoder interface {
    EncodeJSON() ([]byte, error)
}

func (u *User) EncodeJSON() ([]byte, error) {
    return json.Marshal(u)
}

// または Generics で
func ToJSON[T any](value T, encode func(T) ([]byte, error)) ([]byte, error) {
    return encode(value)
}
```

### implicit の使い分けまとめ

| Scala 2 implicit の用途 | Go での代替 |
|------------------------|------------|
| implicit parameter（DI） | コンストラクタ引数 / `context.Context` |
| implicit conversion | 明示的な変換関数（`strconv` 等） |
| implicit class（拡張メソッド） | パッケージ関数 / 型定義 + メソッド |
| 型クラス（`implicit val`） | interface 実装 / Generics |
| `Ordering[T]` 等の標準implicit | `slices.SortFunc` + 比較関数 |
| `ExecutionContext` | Goランタイム（設定不要） |

## 9. パッケージ構成

### Go公式の考え方

Go公式ドキュメント（[Organizing a Go module](https://go.dev/doc/modules/layout)）が唯一の公式ガイダンス。Goのテックリード Russ Cox の言葉：

> Goリポジトリの標準レイアウトは：
> 1. ルートに `LICENSE` を置く
> 2. ルートに `go.mod` を置く
> 3. 好きなようにディレクトリを整理する
>
> **これが「標準」です。**

Goの文化は「必要になるまでディレクトリを増やさない」。Scalaのような深いパッケージ階層は避け、フラットに保つのが基本。

### ScalaとGoのパッケージの違い

| Scala 2 | Go | 備考 |
|---------|-----|------|
| `package com.example.app` | `package app` | Goはフラットなパッケージ名 |
| ネストしたパッケージ | ディレクトリ = パッケージ | 1ディレクトリ1パッケージ |
| `import com.example.app._` | `import "github.com/user/app"` | モジュールパス |
| `import` でワイルドカード `._` | 全エクスポート名が使える | Goは常にパッケージ修飾 `app.Func()` |
| `import { A => B }` リネーム | `import b "path/to/pkg"` | |
| `package object` | パッケージレベル変数/関数 | Go にはpackage objectはない |
| `private[this]` | 小文字始まり（パッケージスコープ） | Goの最小スコープはパッケージ |
| `private[package]` | 小文字始まり | |
| `protected` | なし | Goにprotectedスコープはない |
| サブパッケージからのアクセス | `internal/` パッケージ | 外部から参照不可 |

### 典型的なプロジェクト構成の対応

```
# Scala (sbt マルチプロジェクト)
project/
├── build.sbt
├── domain/
│   └── src/main/scala/com/example/domain/
│       ├── model/User.scala
│       ├── repository/UserRepository.scala
│       └── service/UserService.scala
├── infrastructure/
│   └── src/main/scala/com/example/infra/
│       └── repository/UserRepositoryImpl.scala
└── api/
    └── src/main/scala/com/example/api/
        └── controller/UserController.scala
```

```
# Go (公式推奨に準拠したレイアウト)
# ref: https://go.dev/doc/modules/layout
project/
├── go.mod
├── cmd/                        # 複数バイナリがある場合のみ
│   └── api/
│       └── main.go            # エントリポイント
└── internal/                   # 外部モジュールから参照不可（コンパイラが強制）
    ├── domain/
    │   └── user.go            # User struct + Repository interface
    ├── infra/
    │   └── user_repository.go # Repository実装
    └── handler/
        └── user_handler.go    # HTTPハンドラ
```

> **Note**: `pkg/` ディレクトリは非推奨傾向。`golang-standards/project-layout` が広めたが
> Go公式チーム（Russ Cox）が「Goの標準ではない」と明確に否定している。
> 外部公開したいコードはルート直下に置き、非公開コードは `internal/` に入れるのがGo流。

### 単一バイナリの場合はもっとシンプル

```
# 単一バイナリなら cmd/ すら不要
project/
├── go.mod
├── main.go                    # ルートにmain
└── internal/
    ├── domain/
    │   └── user.go
    └── handler/
        └── user_handler.go
```

### Scalaのパッケージオブジェクト → Goのパッケージレベル定義

```scala
// Scala 2
package object domain {
  type UserID = String
  val MaxRetry = 3
  implicit val defaultOrdering: Ordering[User] = Ordering.by(_.name)
}
```

```go
// Go: パッケージ内の任意のファイルに定義
// domain/types.go
package domain

type UserID = string

const MaxRetry = 3
```

### import の違い

```scala
// Scala 2
import com.example.domain.model.User
import com.example.domain.model._           // ワイルドカード
import com.example.domain.{User, UserID}    // 選択的import
import com.example.{domain => d}             // リネーム
```

```go
// Go
import "github.com/user/project/internal/domain" // パッケージ単位
// 使用時: domain.User, domain.UserID

import d "github.com/user/project/internal/domain" // リネーム

// Goには選択的importはない。常にパッケージ丸ごとimport
// ただし未使用importはコンパイルエラーになる
```

### internal パッケージ（Goの可視性制御）

```
project/
├── internal/          # このディレクトリ以下は外部モジュールから参照不可
│   └── secret/        # project内からのみ import 可能
└── pkg/               # 外部モジュールからも参照可能
    └── public/
```

Scala の `private[package]` に近い制御を `internal/` で実現する。Goコンパイラが強制するため、アクセス制御が確実。

## 10. 関数型プログラミング

| Scala | Go | 備考 |
|-------|-----|------|
| 高階関数 | 関数は第一級市民 | `func(T) U` で型定義可 |
| 無名関数 `x => x + 1` | `func(x int) int { return x + 1 }` | Goは省略記法なし |
| カリー化 `f(a)(b)` | クロージャで手動実装 | |
| 部分適用 | クロージャで手動実装 | |
| `for` 内包表記 | `for` ループ | |
| パイプライン `|>` | メソッドチェーンまたは関数ネスト | |
| 不変データ | Goはミュータブルが基本 | コピーで擬似的に対応 |

## 11. Option / Null安全

| Scala | Go | 推奨パターン |
|-------|-----|------------|
| `Some(v)` | `&v` / `v, true` | ポインタまたはboolフラグ |
| `None` | `nil` / `v, false` | ゼロ値で表現できるなら使う |
| `option.map(f)` | `if v != nil { f(*v) }` | |
| `option.getOrElse(d)` | `if v == nil { return d }` | |
| `option.flatMap(f)` | ネストした `if v != nil` | |
| `Option[T]` を返す | `(*T, error)` / `(T, bool)` | |

```go
// パターン1: ポインタ
func FindUser(id string) *User {  // nil = not found
    // ...
}

// パターン2: 多値返却（明示的）
func FindUser(id string) (User, bool) {
    // ...
    return user, true   // found
    return User{}, false // not found
}

// パターン3: エラーで表現
func FindUser(id string) (*User, error) {
    // ...
    return nil, ErrNotFound
}
```

## 12. テスト

| Scala | Go | 備考 |
|-------|-----|------|
| ScalaTest / specs2 | `testing` パッケージ | 標準ライブラリのみで完結 |
| `describe / it` | `func TestXxx(t *testing.T)` | |
| `should / assert` | `if got != want { t.Errorf(...) }` | assertライブラリもある（testify等） |
| テーブル駆動テスト | `[]struct{ ... }` + `for` | Goの定番パターン |
| `mock` | interfaceで差し替え | Goはinterface + DIが基本 |
| `BeforeAll / AfterAll` | `TestMain(m *testing.M)` | |
| `BeforeEach / AfterEach` | `t.Cleanup(func() {...})` | |
| プロパティベーステスト | `testing/quick` / `gopter` | |

### テーブル駆動テスト

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{
        {"positive", 1, 2, 3},
        {"zero", 0, 0, 0},
        {"negative", -1, -2, -3},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := Add(tt.a, tt.b); got != tt.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

## 13. 依存性注入 / アーキテクチャ

| Scala | Go | 備考 |
|-------|-----|------|
| Guice / MacWire | 手動DI（コンストラクタインジェクション） | `wire` (Google) もある |
| `trait` ミックスイン | 構造体埋め込み | |
| Cake Pattern | interface + struct | |
| `implicit` による暗黙的DI | 明示的に渡す | Goは明示的が正義 |
| `Reader` モナド | `context.Context` / 関数引数 | |

```go
// Scala: class UserService @Inject()(repo: UserRepository)
// Go:
type UserService struct {
    repo UserRepository  // interface型
}

func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}
```

## 14. JSON / シリアライゼーション

| Scala | Go | 備考 |
|-------|-----|------|
| circe / play-json | `encoding/json` | 標準ライブラリ |
| `Json.toJson(obj)` | `json.Marshal(obj)` | |
| `Json.parse(str).as[T]` | `json.Unmarshal(data, &obj)` | |
| `implicit Format[T]` | struct tag `json:"field"` | |
| カスタムcodec | `MarshalJSON()` / `UnmarshalJSON()` | interface実装 |

## 15. HTTP / Web

| Scala | Go | 備考 |
|-------|-----|------|
| Play Framework | `net/http` / Echo / Gin / Chi | 標準でも十分 |
| Akka HTTP | `net/http` | |
| ルーティング DSL | `http.NewServeMux` (Go 1.22+) / Chi | |
| Filter / Middleware | `func(http.Handler) http.Handler` | |
| `Action.async` | ハンドラは同期的に書く（goroutine不要） | |

## 16. ビルド / プロジェクト管理

| Scala | Go | 備考 |
|-------|-----|------|
| sbt | `go build` / `go mod` | ビルドツール不要 |
| `build.sbt` | `go.mod` | 依存管理 |
| `libraryDependencies` | `go get` / `go.mod` の `require` | |
| マルチプロジェクト | Go workspace (`go.work`) | Go 1.18+ |
| `sbt test` | `go test ./...` | |
| `sbt compile` | `go build ./...` | |
| `sbt run` | `go run .` | |
| `sbt assembly` (fat JAR) | `go build`（シングルバイナリ） | Goは常にシングルバイナリ |

## 17. よくあるハマりポイント

### ゼロ値に注意

Goは未初期化変数にゼロ値が入る。Scalaの `null` とは違い、コンパイルは通る。

```go
var s string  // "" (空文字列、nilではない)
var n int     // 0
var b bool    // false
var p *User   // nil
```

### ループ変数のキャプチャ

Go 1.22未満ではループ変数がクロージャで共有される問題があった。Go 1.22+で修正済み。

### interfaceのnil判定

```go
var u *User = nil
var i interface{} = u
fmt.Println(i == nil) // false! interfaceは(type, value)のペア
```

### エラーを無視しない

```go
// 悪い例
result, _ := doSomething()

// 良い例
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doSomething: %w", err)
}
```

## 参考リンク

- [Effective Go](https://go.dev/doc/effective_go)
- [Go by Example](https://gobyexample.com/)
- [Go Wiki: SliceTricks](https://go.dev/wiki/SliceTricks)
- [Go標準ライブラリ](https://pkg.go.dev/std)
- [golang/go: errgroup](https://pkg.go.dev/golang.org/x/sync/errgroup)
