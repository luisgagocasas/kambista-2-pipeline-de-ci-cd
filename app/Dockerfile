FROM node:20-alpine
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY . .

# Inyecta el mensaje del día bajo el título H1 al construir
ARG MENSAJE_DIA
RUN if [ -n "$MENSAJE_DIA" ]; then sed -i "s|<!-- MENSAJE_DIA -->|<p id=\"mensaje-dia\" class=\"muted\">$MENSAJE_DIA<\/p>|" index.html; fi

EXPOSE 3000
CMD ["npm","start"]
