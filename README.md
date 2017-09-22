# ssh-diskmon

指定されたec2インスタンス上で`df`コマンドを実行し、結果を標準出力します。
対象のインスタンスへはbastion(踏み台sshサーバ)経由で接続します。

# 詳細

- インスタンスは付与されている`Name`タグで指定します。
- 接続に使う秘密鍵は `~/.ssh/<インスタンスに設定されている鍵名>.pem` に配置されている前提です


## 使い方

### セットアップ

```
$ git@github.com:cm-kazup0n/ssh-diskmon.git
$ cd ssh-diskmon
$ bundle exec install --path vendor/bundle
```

### hosts.conf

ホストの指定

```
hosts:
    <bastion-name>:
    - target-name-1
    - target-name-2
    <bastion-name2>:
    - target-name-3
    - target-name-4
```

### オプション

```
Usage: diskmon [options]        
        --profile VALUE              profile(default: )
        --show-ssh                   show ssh console login command (default: false)
        --format VALUE               output format (compact, json, table, default: compact)
        --region VALUE               region (default: )
```

ヘルプは `--help` で表示されます


### 実行例

```
$ bundle exec ruby diskmon.rb --profile prd --format table --show-ssh --region eu-west-1
```

## show_ssh.rb

hosts.ymlに定義されたインスタンスのNameとSSH接続コマンドだけを一覧表示します。
デフォルトではjsonフォーマットで出力します。


### jqと一緒に

TBD

### pecoと一緒に

下記の例のように[peco](https://github.com/peco/peco) にパイプしてevalすると簡単にSSH接続ができます

#### fishで使う例

```
eval (bundle exec ruby show_ssh.rb --profile sbj-prd --format table | peco | cut -d '|' -f 2)
```