# ssh-diskmon

指定されたec2インスタンス上で`df`コマンドを実行し、結果を標準出力します。
対象のインスタンスへはbastion(踏み台sshサーバ)経由で接続します。

# 詳細

- インスタンスは付与されている`Name`タグで指定します。
- 接続に使う秘密鍵は `~/.ssh/<インスタンスに設定されている鍵名>.pem` に配置されている前提です

## usage

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


実行

```
$ bundle install --path vendor/bundle
$ bundle exec ruby diskmon.rb
```