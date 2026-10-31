FROM dart:stable AS build
WORKDIR /app
RUN dart pub global activate dart_frog_cli ^1.2.0
ENV PATH="/root/.pub-cache/bin:${PATH}"
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline
RUN dart_frog build

FROM dart:stable
WORKDIR /app
COPY --from=build /app/build ./build
COPY --from=build /app/lib ./lib
COPY --from=build /app/routes ./routes
COPY --from=build /app/.dart_tool/package_config.json ./.dart_tool/package_config.json
COPY --from=build /root/.pub-cache /root/.pub-cache
COPY --from=build /app/pubspec.yaml ./pubspec.yaml
ENV PORT=8080
EXPOSE 8080
CMD ["dart", "build/bin/server.dart"]
