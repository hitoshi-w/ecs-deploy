FROM nginx:1.25.3

COPY /html /var/www
COPY nginx.conf /etc/nginx/conf.d/default.conf