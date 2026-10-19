#pragma once
#include <stdint.h>
#include <stdbool.h>
#pragma GCC visibility push(default)
#ifdef __cplusplus
extern "C" {
#endif
int32_t op_cef_create(void *parent, const char *url, int64_t key);
void op_cef_action(int32_t browser, int32_t action);
void op_cef_close(int32_t browser);
void op_cef_flush(int32_t browser);
void op_cef_enabled(int32_t browser, bool enabled);
void op_cef_ack(int32_t browser, int32_t context, int32_t request, bool accepted);
void op_cef_quit(void);
void op_cef_test(int32_t browser, int32_t action);
void op_cef_query(int32_t browser, const char *payload);
void op_native_start(void);
void op_native_quit(void);
void op_native_event(int64_t key, int32_t browser, const char *event, const char *value);
void op_native_snapshot(int64_t key, int32_t browser, int32_t context, int32_t request, const char *url, const char *json);
void op_native_popup(const char *url);
#ifdef __cplusplus
}
#endif
#pragma GCC visibility pop
