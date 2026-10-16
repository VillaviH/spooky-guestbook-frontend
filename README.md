# Frontend_Repository

Infrastructure as Code (Terraform) y sitio estático de `Frontend_Application` (Spooky Guestbook): un formulario de "firmas de invitados" servido como SPA sin build step, desplegado sobre AWS mediante `S3_Bucket` + `CloudFront_Distribution`.

## Arquitectura

`Frontend_Application` se compone de dos recursos de AWS, definidos en `s3.tf` y `cloudfront.tf`:

- **`S3_Bucket`**: origen privado de los archivos estáticos del sitio (`public/`: HTML, CSS, JS). El bucket tiene bloqueado todo acceso público (`aws_s3_bucket_public_access_block`) y su política solo permite lectura (`s3:GetObject`) al principal de servicio `cloudfront.amazonaws.com`, restringido además al ARN exacto de `CloudFront_Distribution` (`AWS:SourceArn`). Es decir, el bucket **solo** es accesible a través de CloudFront vía Origin Access Control (OAC), nunca directamente.
- **`CloudFront_Distribution`**: CDN que distribuye `Frontend_Application` al público, usando el `S3_Bucket` como origen a través de un Origin Access Control (OAC, no el OAI legacy). Define `default_root_object = "index.html"`, fuerza HTTPS (`viewer_protocol_policy = "redirect-to-https"`) y, para soportar el enrutamiento del lado del cliente de la SPA, incluye Custom Error Responses que traducen los códigos **403 y 404** (cualquier ruta que no exista como objeto en el bucket) a una respuesta `200` sirviendo `/index.html`, dejando que el router de la aplicación resuelva la ruta en el navegador.

## Despliegue

Pasos de despliegue correspondientes a los comandos de Infrastructure as Code (ver también `.github/workflows/deploy.yml`, que automatiza estos mismos pasos en `Frontend_Pipeline`):

1. **Prerrequisitos**: tener instalado Terraform `>= 1.5.0` y credenciales de AWS configuradas (perfil local o variables de entorno `AWS_...`) con permisos sobre S3 y CloudFront.
2. Inicializar Terraform:
   ```bash
   terraform init
   ```
3. (Opcional) Validar la configuración antes de aplicar cambios, igual que hace `Frontend_Pipeline`:
   ```bash
   ./scripts/validate-terraform.sh
   ```
   o directamente `terraform validate`.
4. Aplicar los cambios de infraestructura (crea/actualiza `S3_Bucket` y `CloudFront_Distribution`):
   ```bash
   terraform apply
   ```
   Opcionalmente se puede pasar en este mismo paso la URL de `Backend_API` con `-var="backend_api_base_url=<url>"` (ver la sección [Configuración del endpoint de Backend_API](#configuración-del-endpoint-de-backend_api) para los detalles y matices de esta variable).
5. Sincronizar los archivos estáticos de `public/` al bucket recién creado:
   ```bash
   aws s3 sync public/ s3://$(terraform output -raw s3_bucket_name) --delete
   ```
6. Invalidar la caché de `CloudFront_Distribution` para que sirva el contenido recién sincronizado:
   ```bash
   aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"
   ```
7. Acceder a `Frontend_Application` en el dominio público de CloudFront:
   ```bash
   echo "https://$(terraform output -raw cloudfront_domain_name)"
   ```

## Configuración del endpoint de Backend_API

`Frontend_Application` necesita conocer la URL base de `Backend_API` (el output `api_base_url` de Backend_Repository) para poder hacer las llamadas al API Gateway desde el navegador. Hay dos mecanismos relacionados, con un matiz importante entre ellos:

- **Opción A (la que efectivamente consume el código en el navegador)**: editar `public/js/config.js` y completar `window.SPOOKY_GUESTBOOK_CONFIG.backendApiBaseUrl` con la URL real de `Backend_API`, por ejemplo:
  ```js
  window.SPOOKY_GUESTBOOK_CONFIG = {
    backendApiBaseUrl: "https://abc123.execute-api.us-east-1.amazonaws.com",
  };
  ```
  Sin barra final (`/`). Este archivo debe quedar actualizado **antes** de ejecutar `aws s3 sync` (paso 5 de la sección de despliegue), ya que es un sitio estático sin bundler ni variables de entorno en tiempo de build: el navegador carga este archivo tal cual.

- **Opción B (vía Terraform / pipeline)**: `variables.tf` define la variable `backend_api_base_url`, que se puede pasar con `-var="backend_api_base_url=<url>"` en `terraform apply` (así lo hace `Frontend_Pipeline` en `.github/workflows/deploy.yml`, usando el secret `BACKEND_API_BASE_URL` del repositorio).

  **Importante — distinción honesta sobre el alcance actual de la Opción B**: hoy esta variable de Terraform se recibe y queda disponible dentro del state de Terraform, pero el código actual **no la inyecta automáticamente** dentro de `public/js/config.js`. El valor que de verdad usa el navegador en tiempo de ejecución sigue siendo el de la Opción A. Conectar ambas (por ejemplo, generando `public/js/config.js` a partir de una plantilla usando `backend_api_base_url` como un paso del pipeline, antes del `aws s3 sync`) queda documentado aquí como una mejora futura, no como el comportamiento actual.

## Costo

La estimación de costos de todo el proyecto (incluyendo `Frontend_Application`) se documenta a nivel de Project, no en este README. Ver la tarea 26.3 del spec `aws-serverless-hackathon-demo` (documento de estimación de costos en USD para el escenario de 3 días de hackathon).
