# 認可モデル詳細と選択基準

## 目次

1. [認可モデル概要](#認可モデル概要)
   - [認証と認可の違い](#認証と認可の違い)
   - [主要な認可モデル](#主要な認可モデル)
2. [RBAC(Role-Based Access Control)](#rbacrole-based-access-control)
   - [基本概念](#rbac基本概念)
   - [ロール階層設計](#ロール階層設計)
   - [パーミッション粒度](#パーミッション粒度)
   - [DBスキーマパターン](#rbacのdbスキーマパターン)
   - [実装パターン](#rbacの実装パターン)
3. [ABAC(Attribute-Based Access Control)](#abacattribute-based-access-control)
   - [基本概念](#abac基本概念)
   - [ポリシー設計](#abacポリシー設計)
   - [属性の種類](#属性の種類)
   - [実装パターン](#abacの実装パターン)
4. [リソースベースアクセス制御](#リソースベースアクセス制御)
   - [所有権ベース](#所有権ベース)
   - [共有・委譲パターン](#共有委譲パターン)
   - [実装パターン](#リソースベースの実装パターン)
5. [認可ミドルウェア設計](#認可ミドルウェア設計)
   - [チェックポイント配置](#チェックポイント配置)
   - [ミドルウェアパターン](#ミドルウェアパターン)
   - [エラーハンドリング](#エラーハンドリング)
6. [パーミッションチェック戦略](#パーミッションチェック戦略)
   - [Eager評価](#eager評価)
   - [Lazy評価](#lazy評価)
   - [ハイブリッドアプローチ](#ハイブリッドアプローチ)
7. [マルチテナント認可](#マルチテナント認可)
   - [テナント分離パターン](#テナント分離パターン)
   - [クロステナントアクセス](#クロステナントアクセス)
   - [実装パターン](#マルチテナントの実装パターン)
8. [モデル選択の決定木](#モデル選択の決定木)
   - [選択フローチャート](#選択フローチャート)
   - [ユースケース別推奨](#ユースケース別推奨)
   - [複合アプローチ](#複合アプローチ)

---

## 認可モデル概要

### 認証と認可の違い

**認証(Authentication):**
- 「あなたは誰ですか?」に答える
- ユーザーの身元確認
- ログイン処理

**認可(Authorization):**
- 「あなたは何ができますか?」に答える
- アクセス権限の判定
- リソース保護

### 主要な認可モデル

```
1. RBAC (Role-Based Access Control)
   - ロール(役割)ベースの権限管理
   - シンプルで理解しやすい
   - 多くのシステムで採用

2. ABAC (Attribute-Based Access Control)
   - 属性ベースの権限管理
   - 柔軟で細かい制御
   - 複雑なポリシー表現可能

3. ACL (Access Control List)
   - リソースごとのアクセス制御リスト
   - ファイルシステム等で伝統的

4. ReBAC (Relationship-Based Access Control)
   - 関係性ベースの権限管理
   - ソーシャルネットワーク等に適用

5. PBAC (Policy-Based Access Control)
   - ポリシーベースの権限管理
   - ABACの一般化
```

---

## RBAC(Role-Based Access Control)

### RBAC基本概念

ユーザーにロール(役割)を割り当て、ロールに権限を紐付ける方式。

**基本要素:**

```
ユーザー (User)
  ↓ 割り当て
ロール (Role)
  ↓ 付与
パーミッション (Permission)
  ↓ 対象
リソース (Resource)
```

**例:**

```
ユーザー: 田中太郎
  ↓
ロール: 編集者
  ↓
パーミッション: 記事の作成、編集、削除
  ↓
リソース: 記事
```

### ロール階層設計

#### フラットなロール構造

```
構造:
- 管理者
- 編集者
- 閲覧者

特徴:
- シンプル
- 理解しやすい
- 小規模システム向け
```

#### 階層的ロール構造

```
構造:
システム管理者 (最上位)
  └─ 組織管理者
      ├─ 部門管理者
      │   └─ チームリーダー
      │       └─ メンバー
      └─ 編集者
          └─ 閲覧者

継承ルール:
- 上位ロールは下位ロールの権限を継承
- システム管理者 = 全ての権限
- 編集者 = 閲覧者の権限 + 編集権限

利点:
- 権限管理の効率化
- 柔軟な権限設計

欠点:
- 複雑性の増加
- 循環参照のリスク
```

#### 機能別ロール構造

```
構造:
基本ロール:
- ユーザー
- 編集者
- 管理者

機能別ロール:
- 記事管理者
- ユーザー管理者
- 設定管理者
- レポート閲覧者

組み合わせ:
ユーザーに複数ロール割り当て可能
例: 田中さん = 編集者 + レポート閲覧者

利点:
- 細かい権限制御
- 役割の明確化

実装:
多対多の関係(ユーザー ←→ ロール)
```

### パーミッション粒度

#### 粗い粒度(Coarse-grained)

```
例:
- 記事管理
- ユーザー管理
- システム管理

利点:
- シンプル
- パフォーマンスが良い

欠点:
- 細かい制御が困難
```

#### 細かい粒度(Fine-grained)

```
例:
- 記事作成
- 記事編集
- 記事削除
- 記事公開
- 下書き保存
- コメント管理

利点:
- 詳細な制御可能
- セキュリティ向上

欠点:
- 管理が複雑
- パフォーマンス低下の可能性
```

#### CRUD単位

```
リソース: 記事
パーミッション:
- articles:create
- articles:read
- articles:update
- articles:delete

リソース: ユーザー
パーミッション:
- users:create
- users:read
- users:update
- users:delete

命名規則:
{resource}:{action}

利点:
- 一貫性
- 理解しやすい
- スケーラブル
```

#### アクション指向

```
パーミッション:
- publish_article
- approve_comment
- manage_users
- view_reports
- export_data

利点:
- ビジネスロジックに近い
- 直感的

欠点:
- 統一性に欠ける場合がある
```

### RBACのDBスキーマパターン

#### パターン1: 基本スキーマ

```sql
-- ユーザーテーブル
users
- user_id (PK)
- username
- email
- created_at

-- ロールテーブル
roles
- role_id (PK)
- role_name
- description
- created_at

-- ユーザー-ロール中間テーブル
user_roles
- user_role_id (PK)
- user_id (FK)
- role_id (FK)
- assigned_at
- assigned_by
- UNIQUE(user_id, role_id)

-- パーミッションテーブル
permissions
- permission_id (PK)
- permission_name (例: articles:create)
- resource
- action
- description

-- ロール-パーミッション中間テーブル
role_permissions
- role_permission_id (PK)
- role_id (FK)
- permission_id (FK)
- granted_at
- UNIQUE(role_id, permission_id)
```

#### パターン2: 階層的ロール対応

```sql
-- ロールテーブル(階層対応)
roles
- role_id (PK)
- role_name
- parent_role_id (FK, 自己参照)
- level (階層レベル)
- description

-- ロール階層パス(閉包テーブルパターン)
role_hierarchy
- ancestor_role_id (FK)
- descendant_role_id (FK)
- depth (階層の深さ)
- PRIMARY KEY(ancestor_role_id, descendant_role_id)

利点:
- 階層クエリが効率的
- 権限継承の実装が容易
```

#### パターン3: コンテキスト付きロール

```sql
-- スコープ付きユーザーロール
user_roles
- user_role_id (PK)
- user_id (FK)
- role_id (FK)
- scope_type (例: organization, project, team)
- scope_id (スコープの識別子)
- assigned_at

例:
ユーザーAは:
- 組織Xで「管理者」
- プロジェクトYで「編集者」
- チームZで「メンバー」

クエリ例(ユーザーのプロジェクトYでの権限確認):
SELECT p.permission_name
FROM user_roles ur
JOIN role_permissions rp ON ur.role_id = rp.role_id
JOIN permissions p ON rp.permission_id = p.permission_id
WHERE ur.user_id = ?
  AND ur.scope_type = 'project'
  AND ur.scope_id = ?
```

#### パターン4: 時限ロール

```sql
-- 有効期限付きユーザーロール
user_roles
- user_role_id (PK)
- user_id (FK)
- role_id (FK)
- valid_from (有効開始日時)
- valid_until (有効終了日時)
- is_active (アクティブフラグ)

使用例:
- 一時的な管理者権限付与
- 期間限定アクセス
- 試用期間の管理
```

### RBACの実装パターン

#### パターン1: シンプルなロールチェック

```
擬似コード:

function hasRole(user, roleName):
    return user.roles.includes(roleName)

function requireRole(roleName):
    if not hasRole(currentUser, roleName):
        throw UnauthorizedError

使用例:
requireRole('admin')
# 管理者のみアクセス可能
```

#### パターン2: パーミッションベースチェック

```
擬似コード:

function hasPermission(user, permission):
    for role in user.roles:
        if permission in role.permissions:
            return true
    return false

function requirePermission(permission):
    if not hasPermission(currentUser, permission):
        throw UnauthorizedError

使用例:
requirePermission('articles:delete')
# 記事削除権限が必要
```

#### パターン3: リソース所有権との組み合わせ

```
擬似コード:

function canModifyArticle(user, article):
    # 管理者は常に可能
    if hasRole(user, 'admin'):
        return true

    # 所有者は可能
    if article.author_id == user.id:
        return true

    # 編集者で公開記事なら可能
    if hasRole(user, 'editor') and article.status == 'published':
        return true

    return false
```

#### パターン4: 階層的ロールの権限チェック

```
擬似コード:

function getEffectivePermissions(user):
    permissions = Set()

    for role in user.roles:
        # ロール自身の権限
        permissions.add(role.permissions)

        # 継承された権限
        for ancestorRole in role.ancestors:
            permissions.add(ancestorRole.permissions)

    return permissions

function hasPermission(user, permission):
    effectivePermissions = getEffectivePermissions(user)
    return permission in effectivePermissions
```

#### パターン5: キャッシュ戦略

```
擬似コード:

# ユーザーログイン時
function onUserLogin(user):
    # 権限情報をキャッシュ
    permissions = loadUserPermissions(user.id)
    cache.set("user_permissions:" + user.id, permissions, ttl=3600)

# 権限チェック時
function hasPermission(user, permission):
    # キャッシュから取得
    cachedPermissions = cache.get("user_permissions:" + user.id)

    if cachedPermissions is None:
        # キャッシュミス時はDBから取得
        cachedPermissions = loadUserPermissions(user.id)
        cache.set("user_permissions:" + user.id, cachedPermissions, ttl=3600)

    return permission in cachedPermissions

# ロール/権限変更時
function onRoleChanged(roleId):
    # 影響を受けるユーザーのキャッシュを無効化
    affectedUsers = getUsersByRole(roleId)
    for user in affectedUsers:
        cache.delete("user_permissions:" + user.id)
```

---

## ABAC(Attribute-Based Access Control)

### ABAC基本概念

ユーザー、リソース、環境の属性に基づいて動的にアクセス制御を行う方式。

**基本要素:**

```
Subject (主体): ユーザー、サービス等
  - 属性: role, department, location, clearance_level

Resource (リソース): 保護対象
  - 属性: owner, classification, created_at, type

Action (アクション): 実行する操作
  - 属性: type (read, write, delete等)

Environment (環境): コンテキスト
  - 属性: time, ip_address, device_type, network
```

**決定プロセス:**

```
ポリシー評価:
IF (subject.department == resource.department)
   AND (subject.clearance_level >= resource.classification)
   AND (environment.time BETWEEN 09:00 AND 18:00)
THEN PERMIT
ELSE DENY
```

### ABACポリシー設計

#### ポリシー構造

```
ポリシー:
  - ポリシーID
  - ポリシー名
  - 効果 (Permit / Deny)
  - 対象 (Target)
  - 条件 (Condition)
  - 優先度

例:
ポリシー: "部門内文書アクセス"
効果: Permit
対象:
  - リソースタイプ = "document"
条件:
  - subject.department == resource.department
  - subject.role IN ["employee", "manager"]
  - environment.network == "internal"
優先度: 100
```

#### ポリシー評価順序

```
1. 最も具体的なポリシーから評価
2. 優先度の高いポリシーから評価
3. Denyが1つでもあれば拒否(Deny優先)
4. Permitがあり、Denyがなければ許可
5. 該当ポリシーがなければデフォルト動作(通常Deny)

評価アルゴリズム:
- Deny-overrides: 1つでもDenyがあれば拒否
- Permit-overrides: 1つでもPermitがあれば許可
- First-applicable: 最初にマッチしたポリシーを適用
```

### 属性の種類

#### サブジェクト属性

```
ユーザー属性:
- user_id: ユーザー識別子
- role: ロール
- department: 部署
- location: 所在地
- clearance_level: セキュリティクリアランス
- employment_type: 雇用形態
- hire_date: 入社日
- manager_id: 上司ID

セッション属性:
- authenticated_at: 認証時刻
- mfa_verified: MFA検証済みフラグ
- session_trust_level: セッション信頼レベル
```

#### リソース属性

```
基本属性:
- resource_id: リソース識別子
- resource_type: リソースタイプ
- owner_id: 所有者
- created_at: 作成日時
- updated_at: 更新日時

分類属性:
- classification: 機密度(public, internal, confidential, secret)
- category: カテゴリー
- tags: タグ

所属属性:
- department: 所属部署
- project_id: プロジェクト
- team_id: チーム
```

#### 環境属性

```
時間属性:
- current_time: 現在時刻
- day_of_week: 曜日
- is_business_hours: 営業時間内フラグ

ネットワーク属性:
- ip_address: IPアドレス
- network_type: ネットワーク種別(internal, external, vpn)
- geolocation: 地理的位置

デバイス属性:
- device_type: デバイスタイプ(pc, mobile, tablet)
- os: オペレーティングシステム
- is_managed: 管理デバイスフラグ
```

### ABACの実装パターン

#### パターン1: ポリシー言語ベース

```
ポリシー定義(JSON形式):

{
  "policy_id": "doc_dept_access",
  "effect": "permit",
  "target": {
    "resource": {
      "type": "document"
    }
  },
  "condition": {
    "all": [
      {
        "subject.department": {
          "equals": "resource.department"
        }
      },
      {
        "subject.role": {
          "in": ["employee", "manager"]
        }
      },
      {
        "environment.network": {
          "equals": "internal"
        }
      }
    ]
  }
}

評価エンジン:

function evaluatePolicy(policy, subject, resource, environment):
    # ターゲットチェック
    if not matchTarget(policy.target, resource):
        return NotApplicable

    # 条件評価
    if evaluateCondition(policy.condition, subject, resource, environment):
        return policy.effect
    else:
        return NotApplicable

function evaluateCondition(condition, subject, resource, environment):
    if condition.type == "all":
        return all(evaluateCondition(c, ...) for c in condition.conditions)
    elif condition.type == "any":
        return any(evaluateCondition(c, ...) for c in condition.conditions)
    elif condition.type == "comparison":
        leftValue = getAttribute(condition.left, subject, resource, environment)
        rightValue = getAttribute(condition.right, subject, resource, environment)
        return compare(leftValue, condition.operator, rightValue)
```

#### パターン2: ルールベースエンジン

```
ルール定義:

Rule: DepartmentDocumentAccess
  WHEN:
    resource.type == "document"
    subject.department == resource.department
  THEN:
    PERMIT

Rule: ManagerOverride
  WHEN:
    subject.role == "manager"
    subject.department == resource.department
  THEN:
    PERMIT

Rule: BusinessHoursOnly
  WHEN:
    resource.classification == "confidential"
    NOT (9 <= environment.hour <= 18)
  THEN:
    DENY

評価順序:
1. 全ルールを評価
2. Deny優先
3. マッチするPermitがあれば許可
```

#### パターン3: コードベースポリシー

```
擬似コード:

class DocumentAccessPolicy:
    def evaluate(self, subject, resource, environment):
        # 基本チェック
        if resource.type != "document":
            return NotApplicable

        # 部署一致チェック
        if subject.department != resource.department:
            return Deny

        # 機密文書は営業時間内のみ
        if resource.classification == "confidential":
            if not (9 <= environment.hour <= 18):
                return Deny

        # ロールチェック
        if subject.role in ["employee", "manager"]:
            return Permit

        return Deny

# ポリシー登録
policyEngine.register(DocumentAccessPolicy())

# 評価
result = policyEngine.evaluate(currentUser, document, currentEnvironment)
if result == Permit:
    # アクセス許可
else:
    # アクセス拒否
```

#### パターン4: DBスキーマ

```sql
-- ポリシーテーブル
policies
- policy_id (PK)
- policy_name
- effect (permit/deny)
- priority
- is_active

-- ポリシーターゲット
policy_targets
- target_id (PK)
- policy_id (FK)
- target_type (resource_type, resource_id等)
- target_value

-- ポリシー条件
policy_conditions
- condition_id (PK)
- policy_id (FK)
- parent_condition_id (FK, 階層構造)
- condition_type (comparison, all, any)
- left_operand
- operator (equals, in, greater_than等)
- right_operand

-- 属性定義
attributes
- attribute_id (PK)
- attribute_name
- attribute_type (subject, resource, environment)
- data_type (string, number, boolean, datetime)

-- 属性値(動的属性の場合)
attribute_values
- value_id (PK)
- entity_type (user, resource等)
- entity_id
- attribute_id (FK)
- value
- valid_from
- valid_until
```

---

## リソースベースアクセス制御

### 所有権ベース

リソースの所有者に基づいてアクセスを制御する方式。

**基本概念:**

```
原則:
- ユーザーは自分が作成したリソースを完全に制御できる
- 他人のリソースは基本的にアクセス不可
- 管理者は例外的に全リソースにアクセス可能

実装:
リソーステーブルに owner_id カラムを追加

例:
articles
- article_id
- title
- content
- owner_id (FK -> users)
- created_at
```

**チェックロジック:**

```
擬似コード:

function canAccessArticle(user, article, action):
    # 管理者は全操作可能
    if user.role == "admin":
        return true

    # 所有者チェック
    if article.owner_id == user.id:
        return true

    # 読み取り専用アクションは公開記事のみ
    if action == "read" and article.status == "published":
        return true

    return false
```

### 共有・委譲パターン

#### パターン1: 直接共有

```
実装:
resource_shares テーブル:
- share_id (PK)
- resource_id (FK)
- resource_type
- shared_with_user_id (FK)
- permission_level (read, write, admin)
- shared_by (FK -> users)
- shared_at
- expires_at

チェックロジック:
function canAccessResource(user, resource, action):
    # 所有者チェック
    if resource.owner_id == user.id:
        return true

    # 共有チェック
    share = findShare(resource.id, user.id)
    if share and not share.isExpired():
        return share.permission_level.allows(action)

    return false
```

#### パターン2: グループ共有

```
実装:
groups テーブル:
- group_id (PK)
- group_name
- owner_id (FK)

group_members テーブル:
- membership_id (PK)
- group_id (FK)
- user_id (FK)
- role (member, moderator, admin)

resource_group_shares テーブル:
- share_id (PK)
- resource_id (FK)
- group_id (FK)
- permission_level

チェックロジック:
function canAccessResource(user, resource, action):
    # 所有者チェック
    if resource.owner_id == user.id:
        return true

    # グループ共有チェック
    userGroups = user.getGroups()
    for group in userGroups:
        share = findGroupShare(resource.id, group.id)
        if share and share.permission_level.allows(action):
            return true

    return false
```

#### パターン3: 公開レベル制御

```
実装:
リソースに visibility フィールド追加:
- private: 所有者のみ
- internal: 組織内全員
- public: 全ユーザー

チェックロジック:
function canAccessResource(user, resource, action):
    # 所有者は常に可能
    if resource.owner_id == user.id:
        return true

    # 公開レベルチェック
    if resource.visibility == "public":
        return action == "read"

    if resource.visibility == "internal" and user.organization_id == resource.organization_id:
        return action == "read"

    # 明示的な共有チェック
    return hasExplicitShare(user, resource, action)
```

### リソースベースの実装パターン

#### パターン1: 所有権チェッククエリ

```
SQL例:

-- ユーザーがアクセス可能な記事一覧
SELECT a.*
FROM articles a
WHERE
    -- 所有者
    a.owner_id = :user_id
    OR
    -- 公開記事
    a.visibility = 'public'
    OR
    -- 共有されている
    EXISTS (
        SELECT 1 FROM resource_shares rs
        WHERE rs.resource_id = a.article_id
          AND rs.resource_type = 'article'
          AND rs.shared_with_user_id = :user_id
          AND (rs.expires_at IS NULL OR rs.expires_at > NOW())
    )
    OR
    -- グループ共有
    EXISTS (
        SELECT 1 FROM resource_group_shares rgs
        JOIN group_members gm ON rgs.group_id = gm.group_id
        WHERE rgs.resource_id = a.article_id
          AND gm.user_id = :user_id
    )
```

#### パターン2: ポリシークラス

```
擬似コード:

class ArticlePolicy:
    def canView(self, user, article):
        return (
            self.isOwner(user, article) or
            self.isPublic(article) or
            self.isShared(user, article) or
            self.isAdmin(user)
        )

    def canEdit(self, user, article):
        if self.isAdmin(user):
            return true

        if not self.isOwner(user, article):
            share = self.getShare(user, article)
            return share and share.permission_level in ["write", "admin"]

        return true

    def canDelete(self, user, article):
        return self.isOwner(user, article) or self.isAdmin(user)

    def isOwner(self, user, article):
        return article.owner_id == user.id

    def isPublic(self, article):
        return article.visibility == "public"

    def isShared(self, user, article):
        return findShare(user.id, article.id) is not None

    def isAdmin(self, user):
        return user.role == "admin"

使用例:
policy = ArticlePolicy()
if policy.canEdit(currentUser, article):
    # 編集処理
else:
    throw ForbiddenError()
```

---

## 認可ミドルウェア設計

### チェックポイント配置

```
レイヤー別チェック:

1. ルーティングレイヤー
   - 認証チェック(ログイン必須)
   - 基本的なロールチェック

2. コントローラーレイヤー
   - アクション固有の権限チェック
   - リソースレベルの権限チェック

3. サービスレイヤー
   - ビジネスロジック内での細かい権限チェック
   - データ取得時のフィルタリング

4. データアクセスレイヤー
   - クエリレベルでのアクセス制御
   - テナント分離
```

### ミドルウェアパターン

#### パターン1: デコレーター/アノテーション方式

```
擬似コード:

# ロールベース
@RequireRole("admin")
function deleteUser(userId):
    # 管理者のみ実行可能
    ...

# パーミッションベース
@RequirePermission("articles:delete")
function deleteArticle(articleId):
    # 削除権限が必要
    ...

# 複数条件
@RequireAnyRole(["admin", "moderator"])
function approveComment(commentId):
    # 管理者またはモデレーター
    ...

# カスタムチェック
@AuthorizeResource("article", "id")
function updateArticle(id, data):
    # リソースレベルの権限チェック
    ...

実装例:
function RequirePermission(permission):
    return function(targetFunction):
        return function wrappedFunction(*args, **kwargs):
            if not hasPermission(currentUser, permission):
                throw ForbiddenError("Permission denied: " + permission)
            return targetFunction(*args, **kwargs)
```

#### パターン2: ミドルウェアチェーン

```
擬似コード:

ミドルウェアスタック:
[
    AuthenticationMiddleware(),    # 認証チェック
    RoleMiddleware(["admin"]),     # ロールチェック
    ResourceAuthMiddleware(),      # リソース権限チェック
    RateLimitMiddleware(),         # レート制限
    AuditMiddleware()              # 監査ログ
]

class ResourceAuthMiddleware:
    def process(self, request, next):
        resource = self.loadResource(request)
        action = self.getAction(request)

        if not self.authorize(request.user, resource, action):
            throw ForbiddenError()

        # リソースをリクエストに添付(再取得を避ける)
        request.resource = resource

        return next(request)

    def authorize(self, user, resource, action):
        policy = self.getPolicyFor(resource.type)
        return policy.can(user, resource, action)
```

#### パターン3: ガードパターン

```
擬似コード:

class ArticleGuard:
    def canActivate(self, context):
        request = context.request
        user = request.user
        articleId = request.params.get("id")

        if not user:
            return false

        if articleId:
            article = findArticle(articleId)
            return self.canAccessArticle(user, article)

        return true

    def canAccessArticle(self, user, article):
        return (
            article.owner_id == user.id or
            user.role == "admin" or
            hasShare(user.id, article.id)
        )

ルート定義:
route("/articles/:id", ArticleController.show, guards=[AuthGuard(), ArticleGuard()])
```

### エラーハンドリング

```
エラータイプ:

1. 401 Unauthorized
   - 未認証(ログインしていない)
   - トークン無効/期限切れ

2. 403 Forbidden
   - 認証済みだが権限不足
   - リソースへのアクセス権がない

3. 404 Not Found
   - リソースが存在しない
   - または権限がなく存在を知らせたくない

エラーレスポンス設計:

{
  "error": {
    "code": "FORBIDDEN",
    "message": "このリソースへのアクセス権限がありません",
    "required_permission": "articles:delete",
    "details": {
      "resource_type": "article",
      "resource_id": "12345",
      "action": "delete"
    }
  }
}

セキュリティ考慮:
- 権限不足の詳細を過度に開示しない
- リソースの存在を隠すべき場合は404を返す
- 監査ログには詳細を記録
```

---

## パーミッションチェック戦略

### Eager評価

リクエスト処理の早い段階で権限チェックを行う方式。

**特徴:**

```
タイミング:
- ミドルウェア/ガード層
- コントローラー入口
- リソース取得前

利点:
- 早期に拒否できる
- 無駄な処理を避けられる
- パフォーマンス向上

欠点:
- リソース情報なしでの判定が必要な場合がある
- 複雑な条件判定が困難

適用場面:
- ロールベースの単純なチェック
- リソース非依存のチェック
- 高負荷なリソース取得の前
```

**実装例:**

```
擬似コード:

# ミドルウェアでEagerチェック
class ArticleAuthMiddleware:
    def process(self, request, next):
        # リソース取得前にロールチェック
        action = request.method

        if action == "DELETE":
            # 削除は管理者または編集者のみ
            if not currentUser.hasAnyRole(["admin", "editor"]):
                throw ForbiddenError()

        return next(request)

# コントローラー
function deleteArticle(articleId):
    # ミドルウェアで権限確認済み
    article = findArticle(articleId)  # ここで初めてリソース取得
    article.delete()
```

### Lazy評価

リソース取得後に権限チェックを行う方式。

**特徴:**

```
タイミング:
- リソース取得後
- コントローラー内
- サービスレイヤー

利点:
- リソース情報を使った詳細な判定が可能
- 所有権チェック等が容易

欠点:
- 無駄なリソース取得の可能性
- パフォーマンス低下リスク

適用場面:
- リソース依存の複雑なチェック
- 所有権ベースの制御
- ABACポリシー評価
```

**実装例:**

```
擬似コード:

function updateArticle(articleId, data):
    # まずリソース取得
    article = findArticle(articleId)

    # リソース情報を使って詳細チェック
    if not canModifyArticle(currentUser, article):
        throw ForbiddenError()

    # 更新処理
    article.update(data)

function canModifyArticle(user, article):
    # 所有者チェック
    if article.owner_id == user.id:
        return true

    # 管理者チェック
    if user.role == "admin":
        return true

    # 共有チェック
    share = findShare(user.id, article.id)
    if share and share.permission_level in ["write", "admin"]:
        return true

    return false
```

### ハイブリッドアプローチ

Eager評価とLazy評価を組み合わせる方式。

**戦略:**

```
二段階チェック:

1. Eagerチェック(粗いフィルター)
   - 認証チェック
   - 基本的なロールチェック
   - グローバルな制約

2. Lazyチェック(細かいフィルター)
   - リソース所有権チェック
   - 属性ベースの詳細チェック
   - ビジネスルールチェック

利点:
- 両方の利点を活用
- 段階的な拒否による効率化
- 柔軟な権限制御
```

**実装例:**

```
擬似コード:

# Eagerチェック(ミドルウェア)
class ArticleAuthMiddleware:
    def process(self, request, next):
        # 認証チェック
        if not request.user:
            throw UnauthorizedError()

        # 基本的なロールチェック
        action = request.method
        if action == "POST" and not request.user.hasAnyRole(["author", "editor", "admin"]):
            throw ForbiddenError("記事の作成権限がありません")

        return next(request)

# Lazyチェック(コントローラー)
function updateArticle(articleId, data):
    # リソース取得
    article = findArticle(articleId)

    # 詳細な権限チェック
    policy = ArticlePolicy()
    if not policy.canEdit(currentUser, article):
        throw ForbiddenError("この記事を編集する権限がありません")

    # 更新処理
    article.update(data)
```

### クエリレベルフィルタリング

データ取得時点でアクセス可能なリソースのみを取得する方式。

**実装例:**

```
SQL:

-- ユーザーがアクセス可能な記事のみ取得
function getAccessibleArticles(userId):
    return query("""
        SELECT a.*
        FROM articles a
        WHERE
            -- 所有者
            a.owner_id = :user_id
            OR
            -- 公開記事
            a.is_public = true
            OR
            -- 共有されている
            EXISTS (
                SELECT 1 FROM article_shares s
                WHERE s.article_id = a.id
                  AND s.user_id = :user_id
            )
    """, user_id=userId)

ORMレベル:

function getAccessibleArticles(user):
    query = Article.query()

    # 管理者は全記事
    if user.role == "admin":
        return query.all()

    # 一般ユーザーは権限のある記事のみ
    return query.where(
        or(
            Article.owner_id == user.id,
            Article.is_public == true,
            Article.id.in(getSharedArticleIds(user.id))
        )
    ).all()

利点:
- データ漏洩リスクの低減
- 効率的なデータ取得
- アプリケーション層での追加フィルター不要

欠点:
- クエリの複雑化
- パフォーマンスチューニングが必要
- 動的なクエリ生成の複雑さ
```

---

## マルチテナント認可

### テナント分離パターン

#### パターン1: データベース分離

```
方式:
- テナントごとに独立したデータベース
- 完全な分離

利点:
- 最高レベルのセキュリティ
- パフォーマンス分離
- カスタマイズ容易

欠点:
- コスト増
- 管理複雑性
- スケーラビリティ課題

実装:
function getDatabaseConnection(tenantId):
    config = getTenantConfig(tenantId)
    return connectDatabase(config)

function getArticles(tenantId):
    db = getDatabaseConnection(tenantId)
    return db.query("SELECT * FROM articles")
```

#### パターン2: スキーマ分離

```
方式:
- 同一データベース内でスキーマ分離
- テナントごとに専用スキーマ

実装:
function setTenantSchema(tenantId):
    schemaName = "tenant_" + tenantId
    db.execute("SET search_path TO " + schemaName)

function getArticles():
    # 現在のスキーマから取得
    return db.query("SELECT * FROM articles")
```

#### パターン3: 行レベル分離

```
方式:
- 全テナントが同じテーブルを共有
- テーブルに tenant_id カラムを追加
- クエリで常に tenant_id フィルタ

実装:
テーブル構造:
articles
- article_id (PK)
- tenant_id (FK, インデックス必須)
- title
- content
- created_at

クエリ:
SELECT * FROM articles WHERE tenant_id = :tenant_id

グローバルフィルター実装:
class TenantScope:
    def apply(self, query, tenantId):
        return query.where("tenant_id = ?", tenantId)

# ORMレベルで自動適用
Article.query()  # 自動的に tenant_id フィルタが追加される

利点:
- コスト効率
- 管理が容易
- スケーラブル

欠点:
- セキュリティリスク(実装ミスでデータ漏洩)
- パフォーマンスへの影響
- インデックス戦略が重要
```

### クロステナントアクセス

特定の条件下で他テナントのリソースにアクセスする仕組み。

**ユースケース:**

```
1. テナント間連携
   - 親子会社間のデータ共有
   - パートナー企業間の協業

2. サービスプロバイダー
   - 管理会社による顧客データアクセス
   - サポート業務

3. マーケットプレイス
   - 出品者と購入者間のデータ
```

**実装パターン:**

```
方式1: 明示的な共有テーブル

cross_tenant_shares
- share_id (PK)
- source_tenant_id (FK)
- target_tenant_id (FK)
- resource_type
- resource_id
- permission_level
- valid_from
- valid_until

チェックロジック:
function canAccessResource(user, resource):
    # 同一テナント内アクセス
    if user.tenant_id == resource.tenant_id:
        return checkStandardPermission(user, resource)

    # クロステナント共有チェック
    share = findCrossTenantShare(
        source_tenant_id=resource.tenant_id,
        target_tenant_id=user.tenant_id,
        resource_id=resource.id
    )

    return share and not share.isExpired()

方式2: テナント階層

tenant_hierarchy
- parent_tenant_id (FK)
- child_tenant_id (FK)
- relationship_type (parent, subsidiary, partner)

ルール:
- 親テナントは子テナントのデータにアクセス可能
- 逆は不可(デフォルト)
- 特定の権限設定で双方向も可能
```

### マルチテナントの実装パターン

#### パターン1: テナントコンテキスト管理

```
擬似コード:

# リクエストごとのテナント識別
class TenantContextMiddleware:
    def process(self, request, next):
        # テナントIDの取得
        tenantId = self.extractTenantId(request)

        if not tenantId:
            throw BadRequestError("テナントIDが指定されていません")

        # コンテキストに設定
        TenantContext.set(tenantId)

        try:
            return next(request)
        finally:
            # クリーンアップ
            TenantContext.clear()

    def extractTenantId(self, request):
        # 方法1: サブドメイン
        subdomain = request.host.split('.')[0]
        return findTenantBySubdomain(subdomain)

        # 方法2: カスタムヘッダー
        # return request.headers.get("X-Tenant-ID")

        # 方法3: JWTトークン
        # return request.user.tenant_id

# グローバルスコープでのフィルタ適用
class TenantAwareModel:
    def query(self):
        baseQuery = super().query()
        tenantId = TenantContext.get()

        if tenantId:
            return baseQuery.where("tenant_id = ?", tenantId)
        else:
            throw Exception("テナントコンテキストが設定されていません")
```

#### パターン2: テナント分離の検証

```
擬似コード:

# 開発/テスト時の安全装置
class TenantIsolationGuard:
    def beforeQuery(self, query):
        # SELECTクエリにtenant_idフィルタが含まれているか確認
        if not self.hasTenantFilter(query):
            # 本番環境ではエラー
            if isProduction():
                throw SecurityError("テナントフィルタのないクエリは禁止されています")
            # 開発環境では警告ログ
            else:
                log.warning("テナントフィルタがないクエリ: " + query)

    def hasTenantFilter(self, query):
        return "tenant_id" in query.whereClause

# 監査ログ
class TenantAuditLog:
    def logAccess(self, user, resource, action):
        log({
            "timestamp": now(),
            "user_id": user.id,
            "user_tenant_id": user.tenant_id,
            "resource_type": resource.type,
            "resource_id": resource.id,
            "resource_tenant_id": resource.tenant_id,
            "action": action,
            "cross_tenant": user.tenant_id != resource.tenant_id
        })
```

---

## モデル選択の決定木

### 選択フローチャート

```
システムの認可要件分析
    |
    +--> シンプルなロールベースで十分か?
         |
         +-- YES --> RBAC
         |           - 明確なロール定義
         |           - シンプルな権限体系
         |           - 管理が容易
         |
         +-- NO --> 複雑な条件が必要か?
                    |
                    +-- YES --> 動的な属性評価が必要か?
                    |           |
                    |           +-- YES --> ABAC
                    |           |           - 属性ベースの細かい制御
                    |           |           - 柔軟なポリシー
                    |           |           - コンテキスト考慮
                    |           |
                    |           +-- NO --> リソース所有権中心か?
                    |                      |
                    |                      +-- YES --> リソースベース
                    |                      |           - 所有権制御
                    |                      |           - 共有機能
                    |                      |
                    |                      +-- NO --> RBAC + リソースベース
                    |
                    +-- NO --> RBACで対応可能
```

### ユースケース別推奨

#### ケース1: 社内業務システム

```
特徴:
- 明確な組織階層
- 固定的な役割分担
- 部署ベースのアクセス制御

推奨モデル: RBAC + 階層的ロール

実装:
- 部署ごとのロール定義
- 役職に応じたロール階層
- シンプルなパーミッション管理

例:
- 一般社員: 自部署のデータ閲覧
- 主任: 自部署のデータ編集
- 課長: 自課の全データ管理
- 部長: 自部の全データ管理
```

#### ケース2: SaaSアプリケーション

```
特徴:
- マルチテナント
- テナントごとのカスタマイズ
- 柔軟な権限設定

推奨モデル: RBAC + マルチテナント + リソースベース

実装:
- テナント分離(行レベル)
- テナント内でのロール管理
- リソースの共有機能
- カスタムロール作成機能

例:
- テナント管理者: テナント内全権限
- プロジェクトマネージャー: プロジェクト管理
- メンバー: 割り当てられたタスク
```

#### ケース3: コンテンツ管理システム

```
特徴:
- コンテンツ所有権
- ワークフロー
- 承認プロセス

推奨モデル: リソースベース + ワークフロー統合

実装:
- 所有者ベースのアクセス制御
- ステータスベースの権限変更
- 承認フロー組み込み

例:
- 作成者: 下書き編集可能
- 編集者: レビュー・承認
- 管理者: 公開・削除
```

#### ケース4: 医療・金融システム

```
特徴:
- 厳格なアクセス制御
- 監査要件
- 時間・場所・デバイス制限

推奨モデル: ABAC

実装:
- 多要素の属性評価
- コンテキスト考慮(時間、場所、デバイス)
- 詳細な監査ログ
- リアルタイムポリシー評価

例:
- 医師: 診療時間内、院内ネットワーク、担当患者のみ
- 看護師: 勤務時間内、病棟内、担当病棟の患者のみ
- 事務: 営業時間内、事務エリア、請求データのみ
```

#### ケース5: ソーシャルメディア

```
特徴:
- ユーザー間の関係性
- 柔軟なプライバシー設定
- 動的な共有

推奨モデル: リソースベース + 関係性ベース

実装:
- 投稿の公開範囲設定
- フォロー関係による閲覧制御
- グループベースの共有
- 細かいプライバシー設定

例:
- 公開投稿: 全ユーザー閲覧可能
- フォロワーのみ: フォロワーに限定
- 友達のみ: 双方向フォローのみ
- カスタム: 特定ユーザー・グループ
```

### 複合アプローチ

多くの実際のシステムでは、複数のモデルを組み合わせる。

#### パターン1: RBAC + リソースベース

```
使い分け:
- グローバル権限: RBAC
  - システム管理
  - ユーザー管理
  - 設定管理

- リソース権限: リソースベース
  - ドキュメント
  - プロジェクト
  - タスク

実装:
function canAccessResource(user, resource, action):
    # グローバル権限チェック(RBAC)
    if user.hasPermission("admin:all"):
        return true

    # リソース権限チェック
    if resource.owner_id == user.id:
        return true

    if hasShare(user, resource, action):
        return true

    return false
```

#### パターン2: RBAC + ABAC

```
使い分け:
- 基本権限: RBAC
  - ロールによる大まかな分類
  - 管理しやすい権限体系

- 詳細制御: ABAC
  - 時間・場所制約
  - 属性ベースの動的制御

実装:
function authorize(user, resource, action, environment):
    # 第一段階: RBACチェック
    if not hasRolePermission(user, resource.type, action):
        return false

    # 第二段階: ABACポリシー評価
    policies = getApplicablePolicies(resource.type)
    return evaluatePolicies(policies, user, resource, environment)
```

#### パターン3: 階層的アプローチ

```
レイヤー構造:

1. グローバルレベル(RBAC)
   - システム管理者
   - システム設定

2. テナントレベル(RBAC + マルチテナント)
   - テナント管理者
   - テナント設定

3. プロジェクトレベル(RBAC + リソースベース)
   - プロジェクト管理者
   - メンバー管理

4. リソースレベル(リソースベース)
   - リソース所有者
   - 個別共有

チェックロジック:
function canAccess(user, resource, action):
    # レベル1: グローバル権限
    if user.isSystemAdmin():
        return true

    # レベル2: テナント権限
    if resource.tenant_id != user.tenant_id:
        return false

    if user.isTenantAdmin():
        return true

    # レベル3: プロジェクト権限
    if resource.project_id:
        projectRole = user.getProjectRole(resource.project_id)
        if projectRole and projectRole.hasPermission(action):
            return true

    # レベル4: リソース権限
    return resource.owner_id == user.id or hasShare(user, resource, action)
```

---

## 実装ベストプラクティス

### セキュリティ原則

```
1. デフォルト拒否
   - 明示的な許可がない限り拒否
   - ホワイトリスト方式

2. 最小権限の原則
   - 必要最小限の権限のみ付与
   - 定期的な権限レビュー

3. 権限の分離
   - 重要な操作は複数の権限に分割
   - チェック&バランス

4. 監査ログ
   - 全ての認可決定をログ記録
   - 誰が、いつ、何を、なぜアクセスしたか

5. 定期的なレビュー
   - 権限の定期的な見直し
   - 不要な権限の削除
   - ロールの整理
```

### パフォーマンス最適化

```
1. 権限のキャッシュ
   - ユーザーの権限情報をキャッシュ
   - 適切なTTL設定
   - 変更時の無効化

2. データベースインデックス
   - user_id, role_id等にインデックス
   - 複合インデックスの活用
   - クエリパフォーマンスの監視

3. 効率的なクエリ
   - N+1問題の回避
   - Eager Loading
   - クエリレベルフィルタリング

4. 階層的チェック
   - 安価なチェックを先に実行
   - 高コストな処理は最後に
```

### テスト戦略

```
1. 単体テスト
   - 各ポリシーの個別テスト
   - 境界値テスト
   - エッジケース

2. 統合テスト
   - エンドツーエンドの権限チェック
   - 実際のユースケースシナリオ

3. セキュリティテスト
   - 権限昇格の試行
   - 認可バイパスの試行
   - クロステナントアクセスの検証

4. パフォーマンステスト
   - 大量ユーザー時の性能
   - 複雑なポリシー評価の性能
```

---

このドキュメントは、認可モデルの設計・実装・選択時の包括的なガイドとして活用してください。システムの要件、規模、複雑さに応じて適切なモデルを選択し、必要に応じて複数のモデルを組み合わせることで、安全で効率的な認可システムを構築できます。
