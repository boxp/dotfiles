#!/usr/bin/env bash
# Convert stream-json lines from delegate CLIs into human-readable pane/log output.
set -uo pipefail

FORMAT="${1:-auto}"
MAX_RESULT_LEN="${AI_DELEGATE_RESULT_MAX:-200}"

truncate_text() {
  local text="$1"
  local max="${2:-$MAX_RESULT_LEN}"
  if [ "${#text}" -gt "$max" ]; then
    printf '%s...' "${text:0:max}"
  else
    printf '%s' "$text"
  fi
}

summarize_json_object() {
  local json="$1"
  jq -r '
    if type == "object" then
      (
        .command // .description // .path // .pattern // .query // .url // .file_path //
        .target_file // .file // .glob // .glob_pattern //
        (to_entries | map("\(.key)=\(.value|tostring)") | join(" "))
      ) | tostring
    else
      tostring
    end
  ' <<< "$json" 2>/dev/null || printf '%s' "$json"
}

emit_line() {
  printf '%s\n' "$1"
}

emit_partial() {
  printf '%s' "$1"
}

is_json_object() {
  jq -e . >/dev/null 2>&1 <<< "$1"
}

format_claude_line() {
  local line="$1"
  local type event_type delta_type block_type tool_name input text

  type="$(jq -r '.type // empty' <<< "$line" 2>/dev/null || true)"
  [ -n "$type" ] || return 1

  case "$type" in
    stream_event)
      event_type="$(jq -r '.event.type // empty' <<< "$line")"
      case "$event_type" in
        content_block_start)
          block_type="$(jq -r '.event.content_block.type // empty' <<< "$line")"
          if [ "$block_type" = "tool_use" ]; then
            tool_name="$(jq -r '.event.content_block.name // "tool"' <<< "$line")"
            input="$(jq -c '.event.content_block.input // {}' <<< "$line")"
            emit_line "[tool] ${tool_name} $(summarize_json_object "$input")"
          fi
          ;;
        content_block_delta)
          delta_type="$(jq -r '.event.delta.type // empty' <<< "$line")"
          case "$delta_type" in
            text_delta)
              text="$(jq -r '.event.delta.text // empty' <<< "$line")"
              [ -n "$text" ] && emit_partial "$text"
              ;;
            thinking_delta)
              text="$(jq -r '.event.delta.thinking // empty' <<< "$line")"
              [ -n "$text" ] && emit_partial "$text"
              ;;
          esac
          ;;
        content_block_stop)
          block_type="$(jq -r '.event.content_block.type // empty' <<< "$line")"
          if [ "$block_type" = "text" ] || [ "$block_type" = "thinking" ]; then
            printf '\n'
          fi
          ;;
      esac
      ;;
    assistant)
      while IFS= read -r tool_line; do
        [ -n "$tool_line" ] && emit_line "$tool_line"
      done < <(
        jq -r '
          .message.content[]?
          | select(.type == "tool_use")
          | "[tool] \(.name) \(if .input then (.input | tojson) else "" end)"
        ' <<< "$line" 2>/dev/null || true
      )
      ;;
    user)
      while IFS= read -r result_line; do
        [ -n "$result_line" ] && emit_line "$result_line"
      done < <(
        jq -r '
          .message.content[]?
          | select(.type == "tool_result")
          | (
              if .is_error then "[result:error] " else "[result] " end
            )
            + (
              .content
              | if type == "string" then .
                elif type == "array" then map(select(.type == "text") | .text) | join("")
                else tostring end
            )
            | .[0:200]
        ' <<< "$line" 2>/dev/null || true
      )
      ;;
    result)
      text="$(jq -r '.result // empty' <<< "$line")"
      if [ -n "$text" ]; then
        emit_line "[final] $(truncate_text "$text" 500)"
      fi
      ;;
  esac
}

format_cursor_line() {
  local line="$1"
  local type subtype text tool_name summary

  type="$(jq -r '.type // empty' <<< "$line" 2>/dev/null || true)"
  [ -n "$type" ] || return 1

  case "$type" in
    thinking)
      subtype="$(jq -r '.subtype // empty' <<< "$line")"
      if [ "$subtype" = "delta" ]; then
        text="$(jq -r '.text // empty' <<< "$line")"
        [ -n "$text" ] && emit_partial "$text"
      elif [ "$subtype" = "completed" ]; then
        printf '\n'
      fi
      ;;
    tool_call)
      subtype="$(jq -r '.subtype // empty' <<< "$line")"
      if [ "$subtype" = "started" ]; then
        summary="$(jq -r '
          .tool_call
          | .. | objects
          | select(has("args"))
          | .args
          | .command // .description // .path // .pattern // .query // .url // tojson
        ' <<< "$line" 2>/dev/null | head -1)"
        tool_name="$(jq -r '
          .tool_call
          | .. | objects
          | select(has("shellToolCall")) | "Shell"
          | . // empty
        ' <<< "$line" 2>/dev/null || true)"
        [ -z "$tool_name" ] && tool_name="tool"
        emit_line "[tool] ${tool_name} ${summary:-"(started)"}"
      elif [ "$subtype" = "completed" ]; then
        summary="$(jq -r '
          .tool_call
          | .. | objects
          | select(has("result"))
          | .result
          | .success.stdout // .success.stderr // .error.message // tojson
        ' <<< "$line" 2>/dev/null | head -1)"
        emit_line "[result] $(truncate_text "${summary:-"(completed)"}")"
      fi
      ;;
    assistant)
      text="$(jq -r '.message.content[]? | select(.type == "text") | .text // empty' <<< "$line" 2>/dev/null || true)"
      [ -n "$text" ] && emit_partial "$text"
      ;;
    result)
      text="$(jq -r '.result // empty' <<< "$line")"
      if [ -n "$text" ]; then
        printf '\n'
        emit_line "[final] $(truncate_text "$text" 500)"
      fi
      ;;
  esac
}

format_pi_line() {
  local line="$1"
  local type text

  type="$(jq -r '.type // empty' <<< "$line" 2>/dev/null || true)"
  [ -n "$type" ] || return 1

  case "$type" in
    message_start|message_end)
      while IFS= read -r content_line; do
        [ -n "$content_line" ] && emit_line "$content_line"
      done < <(
        jq -r '
          .message.content[]?
          | if .type == "text" then .text
            elif .type == "toolCall" then "[tool] \(.name // "tool") \(.arguments // .input // "" | tojson)"
            elif .type == "tool_use" then "[tool] \(.name // "tool") \(.input // {} | tojson)"
            else empty end
        ' <<< "$line" 2>/dev/null || true
      )
      ;;
    turn_end)
      while IFS= read -r result_line; do
        [ -n "$result_line" ] && emit_line "$result_line"
      done < <(
        jq -r '
          .toolResults[]?
          | "[result] "
            + (
              .content // .output // .result // .
              | if type == "string" then . else tojson end
            )
            | .[0:200]
        ' <<< "$line" 2>/dev/null || true
      )
      text="$(jq -r '.message.errorMessage // empty' <<< "$line")"
      [ -n "$text" ] && emit_line "[error] $text"
      ;;
    agent_end)
      text="$(jq -r '.messages[-1].errorMessage // empty' <<< "$line")"
      [ -n "$text" ] && emit_line "[error] $text"
      ;;
  esac
}

detect_format_from_line() {
  local line="$1"
  local type subtype

  type="$(jq -r '.type // empty' <<< "$line" 2>/dev/null || true)"
  subtype="$(jq -r '.subtype // empty' <<< "$line" 2>/dev/null || true)"

  case "$type" in
    stream_event|rate_limit_event) printf 'claude\n' ;;
    tool_call) printf 'cursor\n' ;;
    agent_start|turn_start|turn_end|auto_retry_start) printf 'pi\n' ;;
    thinking)
      if [ "$subtype" = "delta" ] || [ "$subtype" = "completed" ]; then
        printf 'cursor\n'
      fi
      ;;
    assistant|user|result)
      if jq -e 'has("event") or has("parent_tool_use_id")' >/dev/null 2>&1 <<< "$line"; then
        printf 'claude\n'
      elif jq -e 'has("session_id") and has("timestamp_ms")' >/dev/null 2>&1 <<< "$line"; then
        printf 'cursor\n'
      elif jq -e '.message.role? == "assistant" or .message.role? == "user"' >/dev/null 2>&1 <<< "$line"; then
        if jq -e 'has("timestamp_ms")' >/dev/null 2>&1 <<< "$line"; then
          printf 'cursor\n'
        else
          printf 'claude\n'
        fi
      fi
      ;;
  esac
}

format_line() {
  local line="$1"
  local fmt="$2"
  local detected=""

  if [ "$fmt" = "off" ] || [ "$fmt" = "none" ]; then
    emit_line "$line"
    return 0
  fi

  if ! is_json_object "$line"; then
    emit_line "$line"
    return 0
  fi

  if [ "$fmt" = "auto" ]; then
    detected="$(detect_format_from_line "$line")"
    if [ -z "$detected" ]; then
      emit_line "$line"
      return 0
    fi
    fmt="$detected"
  fi

  case "$fmt" in
    claude) format_claude_line "$line" ;;
    cursor) format_cursor_line "$line" ;;
    pi) format_pi_line "$line" ;;
    *) emit_line "$line" ;;
  esac
}

while IFS= read -r line || [ -n "${line:-}" ]; do
  format_line "$line" "$FORMAT"
done
