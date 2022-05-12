FROM cirrusci/flutter:2.13.0-0.4.pre AS builder

WORKDIR /app

COPY . .

RUN flutter pub get
RUN flutter build web --release

FROM nginx:1.20-alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
