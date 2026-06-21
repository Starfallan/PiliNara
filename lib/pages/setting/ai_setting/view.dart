import 'package:PiliPlus/pages/setting/ai_setting/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AiSettingPage extends StatelessWidget {
  const AiSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AiSettingController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 视频总结设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 总开关
          Obx(() => SwitchListTile(
                title: const Text('启用 AI 视频助手'),
                subtitle: const Text('关闭后视频详情页不再显示 AI 按钮'),
                value: controller.enableAiChat.value,
                onChanged: (value) {
                  controller.enableAiChat.value = value;
                  Pref.enableAiChat = value;
                },
              )),
          const SizedBox(height: 8),

          // API 配置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API 配置', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.apiUrlCtl,
                    decoration: const InputDecoration(
                      labelText: '接口地址',
                      hintText: 'https://api.example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    onChanged: controller.saveApiUrl,
                  ),
                  const SizedBox(height: 12),
                  _ApiKeyField(controller: controller),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 模型选择
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('模型选择', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Obx(
                        () => controller.isLoadingModels.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton.filled(
                                icon: const Icon(Icons.refresh),
                                tooltip: '拉取模型列表',
                                onPressed: controller.fetchModels,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    if (controller.modelList.isNotEmpty) {
                      return DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: controller.modelList
                                .contains(controller.model.value)
                            ? controller.model.value
                            : null,
                        items: controller.modelList
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.smart_toy),
                        ),
                        onChanged: (value) {
                          if (value != null) controller.saveModel(value);
                        },
                      );
                    }
                    return TextField(
                      controller: controller.modelCtl,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: 'gpt-5.4',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.smart_toy),
                      ),
                      onChanged: controller.saveModel,
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 模板管理
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('提示词模板', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('恢复默认'),
                        onPressed: () => _confirmRestoreDefaults(
                          context,
                          controller,
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加'),
                        onPressed: () =>
                            _showTemplateDialog(context, controller),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    if (controller.templates.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            '暂无模板，点击上方添加',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ),
                      );
                    }
                    return ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.templates.length,
                      onReorder: controller.reorderTemplate,
                      itemBuilder: (context, index) {
                        final t = controller.templates[index];
                        return Card(
                          key: ValueKey('${t.name}_$index'),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.prompt,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showTemplateDialog(
                                    context,
                                    controller,
                                    index: index,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colorScheme.error,
                                  ),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      controller.deleteTemplate(index),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.drag_handle,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Info card
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '使用说明',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 支持 OpenAI 兼容的 API 接口\n'
                    '• 在视频详情页点击 AI 按钮使用\n'
                    '• 点击「分析」自动载入视频上下文，也可手动载入后自由提问\n'
                    '• 无字幕时仍可使用通用问答\n'
                    '• 支持 Markdown 和 LaTeX，时间戳可点击跳转\n'
                    '• 内置模板名称（概貌总结、详细分析）的内容会被版本更新覆盖\n'
                    '• 自定义模板请使用不同名称，避免与内置模板重名',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _confirmRestoreDefaults(
    BuildContext context,
    AiSettingController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认模板'),
        content: const Text('将清除所有自定义模板，恢复为内置默认模板。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: ColorScheme.of(context).outline),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.restoreDefaults();
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showTemplateDialog(
    BuildContext context,
    AiSettingController controller, {
    int? index,
  }) {
    final isEdit = index != null;
    final existing = isEdit ? controller.templates[index] : null;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final promptCtl = TextEditingController(text: existing?.prompt ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? '编辑模板' : '添加模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: '模板名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptCtl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '提示词内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: ColorScheme.of(context).outline),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtl.text.trim();
              final prompt = promptCtl.text.trim();
              if (name.isEmpty || prompt.isEmpty) return;
              if (isEdit) {
                controller.updateTemplate(index, name, prompt);
              } else {
                controller.addTemplate(name, prompt);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyField extends StatefulWidget {
  const _ApiKeyField({required this.controller});
  final AiSettingController controller;

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller.apiKeyCtl,
      decoration: InputDecoration(
        labelText: 'API Key',
        hintText: 'sk-...',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.key),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.controller.saveApiKey,
    );
  }
}
