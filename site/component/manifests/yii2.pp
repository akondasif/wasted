class component::yii2 (
  $path             = hiera('path', '/var/www/app_name'),
  $vhost            = hiera('vhost', 'app-name.dev'),
  $vhost_port       = 80,
  $env              = hiera('env', 'dev'),
  $front_controller = undef,
) {

  $entrypoint = $front_controller ? {
    undef => $env ? {
      /test/  => 'index-test.php',
      default => 'index.php'
    },
    default => $front_controller
  }

  $location_index = regsubst($entrypoint, '\.', '\.')

  nginx::resource::vhost { "${vhost}-${vhost_port}-yii2":
    server_name => [$vhost],
    listen_port => $vhost_port,
    www_root    => "${path}/web",
    index_files => [$entrypoint],
    try_files   => ['$uri', '@rewriteapp'],
  }

  nginx::resource::location { '@rewriteapp':
    vhost         => "${vhost}-${vhost_port}-yii2",
    www_root      => "${path}/web",
    rewrite_rules => ["^(.*)\$ /${entrypoint}/\$1 last"]
  }

  nginx::resource::location { "~ ^/${location_index}(/|\$)":
    vhost               => "${vhost}-${vhost_port}-yii2",
    www_root            => "${path}/web",
    fastcgi             => '127.0.0.1:9000',
    fastcgi_split_path  => '^(.+\.php)(/.+)$',
    location_cfg_append => {
      fastcgi_buffer_size       => '128k',
      fastcgi_buffers           => '4 256k',
      fastcgi_busy_buffers_size => '256k',
      fastcgi_param => [
        'SCRIPT_FILENAME $document_root/index.php',
        "YII_ENV ${env}"
      ]
    }
  }

  if defined(Class['::hhvm']) {
    nginx::resource::vhost { "hhvm.${vhost}-${vhost_port}-yii2":
      server_name => ["hhvm.${vhost}"],
      listen_port => $vhost_port,
      www_root    => "${path}/web",
      index_files => [$entrypoint],
      try_files   => ['$uri', '@rewriteapp'],
    }

    nginx::resource::location { 'hhvm-yii2-rewrite':
      location      => '@rewriteapp',
      vhost         => "hhvm.${vhost}-${vhost_port}-yii2",
      www_root      => "${path}/web",
      rewrite_rules => ["^(.*)\$ /${entrypoint}/\$1 last"]
    }

    nginx::resource::location { 'hhvm-yii2-php':
      location            => "~ ^/${location_index}(/|\$)",
      vhost               => "hhvm.${vhost}-${vhost_port}-yii2",
      www_root            => "${path}/web",
      fastcgi             => '127.0.0.1:9090',
      fastcgi_split_path  => '^(.+\.php)(/.+)$',
      location_cfg_append => {
        fastcgi_buffer_size       => '128k',
        fastcgi_buffers           => '4 256k',
        fastcgi_busy_buffers_size => '256k',
        fastcgi_param => [
          'SCRIPT_FILENAME $document_root/index.php',
          "YII_ENV ${env}"
        ]
      }
    }
  }
}
