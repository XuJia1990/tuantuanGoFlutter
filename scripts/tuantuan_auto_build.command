#!/bin/zsh
set -euo pipefail

SCRIPT_PATH="${0:A}"
SCRIPT_DIR="${SCRIPT_PATH:h}"
PROJECT_DIR="${PROJECT_DIR:-${SCRIPT_DIR:h}}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$HOME/Desktop/tuantuan_builds}"

APP_ENV=""
TARGET=""
IOS_EXPORT_METHOD=""
CLEAN=false
SKIP_ANALYZE=false
OPEN_OUTPUT=true
POSITIONAL=()

usage() {
  cat <<'EOF'
TuanTuan Flutter build script

Usage:
  ./scripts/tuantuan_auto_build.command [uat|prod] [apk|ipa] [options]

Examples:
  ./scripts/tuantuan_auto_build.command
  ./scripts/tuantuan_auto_build.command uat apk
  ./scripts/tuantuan_auto_build.command prod ipa

Options:
  --ios-export-method <method>
                   iOS export method: development, ad-hoc, app-store, enterprise
  --clean          Run flutter clean before building
  --skip-analyze   Skip flutter analyze
  --no-open        Do not open output folder after build
  -h, --help       Show help

Notes:
  uat  => --dart-define=APP_ENV=uat  => https://api-uat.tuantuan-go.com
  prod => --dart-define=APP_ENV=prod => https://api.tuantuan-go.com
EOF
}

for arg in "$@"; do
  case "$arg" in
    --ios-export-method)
      echo "错误：--ios-export-method 需要写成 --ios-export-method=development 这种形式。"
      exit 1
      ;;
    --ios-export-method=*)
      IOS_EXPORT_METHOD="${arg#*=}"
      ;;
    --clean)
      CLEAN=true
      ;;
    --skip-analyze|--no-analyze)
      SKIP_ANALYZE=true
      ;;
    --no-open)
      OPEN_OUTPUT=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$arg")
      ;;
  esac
done

APP_ENV="${POSITIONAL[1]:-}"
TARGET="${POSITIONAL[2]:-}"

if [[ -z "$APP_ENV" ]]; then
  echo "请选择打包环境："
  echo "  1) uat  测试环境"
  echo "  2) prod 生产环境"
  read "choice?输入 1/2，默认 1: "
  case "${choice:-1}" in
    2|prod|production)
      APP_ENV="prod"
      ;;
    *)
      APP_ENV="uat"
      ;;
  esac
fi

case "$APP_ENV" in
  uat)
    ;;
  prod|production)
    APP_ENV="prod"
    ;;
  *)
    echo "错误：环境只能是 uat 或 prod，当前是：$APP_ENV"
    exit 1
    ;;
esac

if [[ -z "$TARGET" ]]; then
  echo ""
  echo "请选择打包类型："
  echo "  1) apk        Android APK，仅 arm64-v8a"
  echo "  2) ipa        iOS IPA"
  read "choice?输入 1/2，默认 1: "
  case "${choice:-1}" in
    2|ipa)
      TARGET="ipa"
      ;;
    *)
      TARGET="apk"
      ;;
  esac
fi

case "$TARGET" in
  apk|ipa)
    ;;
  android)
    TARGET="apk"
    ;;
  *)
    echo "错误：打包类型只能是 apk 或 ipa，当前是：$TARGET"
    exit 1
    ;;
esac

if [[ "$TARGET" == "ipa" && -z "$IOS_EXPORT_METHOD" ]]; then
  echo ""
  echo "请选择 iOS 导出方式："
  echo "  1) development  真机测试安装，使用开发证书/开发描述文件"
  echo "  2) ad-hoc       指定设备安装，使用发布证书/Ad Hoc 描述文件"
  echo "  3) app-store    上传 TestFlight/App Store，不能直接安装到手机"
  echo "  4) enterprise   企业分发"
  read "choice?输入 1/2/3/4，默认 1: "
  case "${choice:-1}" in
    2|ad-hoc)
      IOS_EXPORT_METHOD="ad-hoc"
      ;;
    3|app-store)
      IOS_EXPORT_METHOD="app-store"
      ;;
    4|enterprise)
      IOS_EXPORT_METHOD="enterprise"
      ;;
    *)
      IOS_EXPORT_METHOD="development"
      ;;
  esac
fi

case "$IOS_EXPORT_METHOD" in
  ""|development|ad-hoc|app-store|enterprise)
    ;;
  *)
    echo "错误：iOS 导出方式只能是 development、ad-hoc、app-store 或 enterprise，当前是：$IOS_EXPORT_METHOD"
    exit 1
    ;;
esac

if [[ -t 0 && "$CLEAN" == false ]]; then
  echo ""
  read "do_clean?是否先执行 flutter clean？[y/N]: "
  if [[ "${do_clean:-N}" == [yY] ]]; then
    CLEAN=true
  fi
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "错误：找不到 Flutter 项目目录：$PROJECT_DIR"
  exit 1
fi

cd "$PROJECT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "错误：找不到 flutter 命令，请先确认 Flutter 已加入 PATH。"
  exit 1
fi

VERSION_LINE="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1)"
BUILD_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE#*+}"
if [[ "$BUILD_NUMBER" == "$VERSION_LINE" ]]; then
  BUILD_NUMBER="0"
fi

STAMP="$(date '+%Y%m%d_%H%M%S')"
OUTPUT_DIR="$OUTPUT_ROOT/${APP_ENV}_${TARGET}_${STAMP}"
mkdir -p "$OUTPUT_DIR"

run() {
  echo ""
  echo ">>> $*"
  "$@"
}

copy_artifact() {
  local src="$1"
  local ext="$2"
  if [[ ! -f "$src" ]]; then
    echo "警告：未找到产物：$src"
    return 1
  fi
  local dst="$OUTPUT_DIR/tuantuan_${APP_ENV}_v${BUILD_NAME}_${BUILD_NUMBER}_${STAMP}.${ext}"
  cp "$src" "$dst"
  echo "已复制：$dst"
}

build_apk() {
  run flutter build apk --release --target-platform android-arm64 --split-per-abi --dart-define=APP_ENV="$APP_ENV"
  local apk_file="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  if [[ -f "$apk_file" ]]; then
    local dst="$OUTPUT_DIR/tuantuan_${APP_ENV}_arm64-v8a_v${BUILD_NAME}_${BUILD_NUMBER}_${STAMP}.apk"
    cp "$apk_file" "$dst"
    echo "已复制：$dst"
    return
  fi
  copy_artifact "build/app/outputs/flutter-apk/app-release.apk" "apk"
}

build_ipa() {
  run flutter build ipa --release --export-method "$IOS_EXPORT_METHOD" --dart-define=APP_ENV="$APP_ENV"
  local ipa_file
  ipa_file="$(find build/ios/ipa -maxdepth 1 -type f -name '*.ipa' | head -n 1 || true)"
  if [[ -z "$ipa_file" ]]; then
    echo "警告：未找到 IPA。请检查 iOS 签名、证书、描述文件或 Xcode 配置。"
    return 1
  fi
  copy_artifact "$ipa_file" "ipa"
}

echo "========================================"
echo "团团 Flutter 自动打包"
echo "项目：$PROJECT_DIR"
echo "环境：$APP_ENV"
echo "类型：$TARGET"
if [[ "$TARGET" == "ipa" ]]; then
  echo "iOS导出：$IOS_EXPORT_METHOD"
fi
echo "版本：$BUILD_NAME+$BUILD_NUMBER"
echo "输出：$OUTPUT_DIR"
echo "========================================"

if [[ "$CLEAN" == true ]]; then
  run flutter clean
fi

run flutter pub get

if [[ "$SKIP_ANALYZE" == false ]]; then
  run flutter analyze
fi

case "$TARGET" in
  apk)
    build_apk
    ;;
  ipa)
    build_ipa
    ;;
esac

echo ""
echo "打包完成：$OUTPUT_DIR"

if [[ "$OPEN_OUTPUT" == true ]]; then
  open "$OUTPUT_DIR" || true
fi
