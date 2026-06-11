# Универсальный helm-чарт для деплоя приложений

Возможности:

- [x] Создание и монтирование volumes + добавочный блок для кастомного монтирования
- [x] Создание секретов из файлов в папке files и монтирование их в деплоймент
- [x] Задание различных портов для service, проброс на initcontainers
- [x] Создание нескольких Ingress.  Возможность переопределить порт и сервис для кажой Path
- [x] Работает с k8s 1.18 -> 1.23
- [x] Readness/liveness/startup пробы
- [x] Lifecycle-команды и возможность переопределить ARGS/CMD
- [x] Создание pull-secrets
- [x] Создание servicemonitor
- [x] InitContainers, sidecars
- [x] hostAliases
- [x] Дополнительные аннотации и лейблы
- [x] Генерация secretproviderclass для vault
- [x] Создание RBAC / psp
- [x] Проброс ENV-переменных в деплоймент

## Быстрый старт
Общий принцип построения деплоя
- В проекте создаём папку `deploy-config`  и копируем в неё `values.yaml` исходного чарта. Копировать лучше под именем `dev|stg|prod-имя_проекта.yaml`, например: `dev-myproject.yaml` - в дальнейшем мы сможем обращаться к разным файлам при помощи gitlab-ci переменной `$CI_ENVIRONMENT_SLUG` 
- Правим ваш конфиг. Обычно нас интересуют переменные для регистри, тэг образа, credentials для pullsecret и ingress
```
image:
  repository: "$CI_REGISTRY_IMAGE"
  tag: "$CI_COMMIT_REF_SLUG-$CI_COMMIT_SHORT_SHA"
  digest: ""
  pullPolicy: "Always"

#create secret for imagepull
imageCredentials:
  createSecret: true
  secretName: regcred
  registry: "$CI_REGISTRY"
  username: "$CI_REGISTRY_USER"
  password: "$CI_REGISTRY_PASSWORD"
#mount pullsecret
imagePullSecrets:
  - name: regcred
```
По умолчанию мы настраиваемся на текущий репозиторий. Образа должны быть тэгированы "регистри/приложение:ветка-коммит".
```
ingresses: 
  - name: ingress-external
    enabled: true
    className: ""
    annotations: {}
    #  kubernetes.io/ingress.class: nginx
    #  nginx.org/proxy-connect-timeout: "60s"
    #  nginx.org/proxy-read-timeout: "60s"
    #  nginx.org/client-max-body-size: "20m"
    #  kubernetes.io/tls-acme: "true"
    hosts:
      - host: $URL
        paths:
          - path: /
            pathType: ImplementationSpecific
            serviceName: ""   # override service, default will be  $fullName
            servicePort: ""   # override port default will be $svcPort
    tls: []
    #  - secretName: ca-secret
    #    hosts:
    #      - $URL
```
Блок ингрессов представляет собой массив, где вы можете задать несколько ингрессов. В нашем случае вы дополнительно можете указать альтернативный порт и имя сервиса в ингрессе
- Рендер конфигурационного файла
```
script:
  - envsubst < ./deploy-config/$CI_ENVIRONMENT_SLUG-myproject.yaml > deploy-config.yaml
  - helm secrets upgrade --install --create-namespace --namespace project-$CI_ENVIRONMENT_SLUG -f ./deploy-config.yaml  $CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG ./deploy
```
Утилита `envsubst` заменяет в текстовом потоке все вхождения переменных, на соответствующие переменные из ENV. Часть переменных гитлаб генерирует автоматически, какие-то вы должны задать в своём проекте в разделе CI/CD
Вместо утилиты `envsubst` можно использовать соотвествующий драйвер для helm-secrets, тогда деплой можно заменить одной строкой
`HELM_SECRETS_DRIVER=envsubst helm secrets upgrade --install --create-namespace --namespace project-$CI_ENVIRONMENT_SLUG -f ./deploy-config/$CI_ENVIRONMENT_SLUG-myproject.yaml $CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG ./deploy`
#Проброс ENV-переменный в контейнер при старте
В блоке `ENV` объявляется переменные которые будут проброшены внутрь контейнера.
```
env:
            - name: http_proxy
              value: "Your_http_proxy"
            - name: https_proxy
              value: "Your_https_proxy"
            - name: no_proxy
              value: "Your_no_proxy,google.com,*.google.com"
```
Т.к. некоторые переменные передавать в открытом виде не лучшая практика, то 
```
env:
            - name: http_proxy
              value: $http_proxy  #Ссылаемся на имя указанное в CI/CD -> Variables
            - name: https_proxy 
              value: $https_proxy
            - name: no_proxy
              value: $no_proxy
```
В Variables есть настройки `Type` и `Environment`
`Type` нужен для того чтоб указать воспринимать переменные как обычные переменные или как файл (гитлаб создаст файл с содержимым данной переменной и сохранит путь в $VAR).
`Environment` нужно для того чтоб разграничивать в каком окружении могут использоваться переменные, чтоб не допустить случайного проброса переменной в ненужную среду, по-умолчанию окружение указывается как `default`, для создания своего окружения необходимо добавить его с соответствующим именем (обычно `dev/stg/prod`)
Чтобы добавить переменные из определённого окружения, необходимо указать его в деплое, в конце блока 
``` 
...
  ...
environment:
  name: dev

```
Конфигурационные файлы

Для того чтобы добавить конфигурационные файлы в контейнер с приложением необходимо проделать проделать следующие действия:
1. Добавляем переменные из конфигурационного файла в `Gitlab Variables` и выбираем тип `File`
2. Переходим в чарт `dev-myproject.yaml` и добавляем следующий блок:
```
confFiles:
  mounts:
    - mountPath: /app/config.yaml   #полный путь куда будет смонтирован файл внутри контейнера
      subPath: config.yaml
      items:
        - key: config.yaml
          path: config.yaml 
    

  files:
    - name: config.yaml
      file: config.yaml # путь к файлу относительно папки с установочным helm-чартом. В данном случае мы будем подбрасывать файлы в корень.
```
**Обратите внимание, что в нашем примере 6 раз встречается `config.yaml` - рекомендуем для каждого монтированного файла делать аналогичным способом (чтобы subPath/key/path совпадал), это убережёт от возможных ошибок**

## Пример файла .gitlab-ci.yml##
Можно найти в репозитории `.gitlab-ci-sample.yml`
