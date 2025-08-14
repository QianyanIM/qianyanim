import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class PhoneResetPasswordPage extends StatefulWidget {
  final String homeserver;
  const PhoneResetPasswordPage({required this.homeserver, super.key});

  @override
  State<PhoneResetPasswordPage> createState() => _PhoneResetPasswordPageState();
}

class _PhoneResetPasswordPageState extends State<PhoneResetPasswordPage> {
  // 表单键
  final _formKey = GlobalKey<FormState>();

  // 控制器
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imageCaptchaController = TextEditingController();

  // 状态变量
  bool _isObscure = true;
  bool _isCountingDown = false;
  int _countdownSeconds = 60;
  bool _isLoading = false;
  Uint8List? _captchaImageData; // 图片验证码数据
  String? _captchaToken; // 图片验证码标识，用于后端验证

  @override
  void initState() {
    super.initState();
    // 初始化时加载图片验证码
    _loadImageCaptcha();
  }

  // 加载图片验证码
  Future<void> _loadImageCaptcha() async {
    try {
      final homeserver = widget.homeserver;
      final url = Uri.parse('$homeserver/_matrix/client/captcha');
      debugPrint('加载图片验证码url: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // 假设API返回JSON，包含图片base64和token
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('$result');

        setState(() {
          // 将base64字符串转换为Uint8List
          _captchaImageData = base64Decode(
            result['image']
                .toString()
                .substring('data:image/png;base64,'.length),
          );
          _captchaToken = result['token']; // 保存验证码标识
        });
      } else {
        _showSnackBar('加载验证码失败，请重试');
      }
    } catch (e) {
      debugPrint('加载图片验证码异常: $e');
      _showSnackBar('网络异常，无法加载验证码');
    }
  }

  // 刷新图片验证码
  void _refreshImageCaptcha() {
    _imageCaptchaController.clear();
    _loadImageCaptcha();
  }

  // 开始倒计时获取手机验证码
  void _startCountdown() {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('请输入手机号');
      return;
    }

    if (!_isPhoneNumberValid(_phoneController.text)) {
      _showSnackBar('请输入有效的手机号');
      return;
    }

    if (_imageCaptchaController.text.isEmpty) {
      _showSnackBar('请输入图片验证码');
      return;
    }

    // 调用API获取手机验证码（带图片验证码验证）
    _fetchVerificationCode();
  }

  // 调用后端API获取手机验证码
  Future<void> _fetchVerificationCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final homeserver = widget.homeserver;
      final url =
          Uri.parse('$homeserver/_matrix/client/send-verification-code');
      debugPrint('获取手机验证码url: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': _phoneController.text,
          'captchaCode': _imageCaptchaController.text, // 图片验证码内容
          'captchaToken': _captchaToken, // 图片验证码标识
        }),
      );

      final result = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && result['success']) {
        // 验证码发送成功，开始倒计时
        setState(() {
          _isCountingDown = true;
          _countdownSeconds = 60;
        });

        _showSnackBar(result['message'] ?? '验证码已发送，请注意查收');

        // 启动倒计时定时器
        final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _countdownSeconds--;
            if (_countdownSeconds <= 0) {
              _isCountingDown = false;
              timer.cancel();
            }
          });
        });

        // 页面销毁时取消定时器
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            timer.cancel();
          }
        });
      } else {
        // 验证码发送失败，刷新图片验证码
        _refreshImageCaptcha();
        _showSnackBar(result['message'] ?? '获取验证码失败，请重试');
      }
    } catch (e) {
      debugPrint('获取手机验证码异常: $e');
      _showSnackBar('网络异常，请检查网络连接');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 提交重置密码表单
  Future<void> _submitResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 替换为实际的重置密码API地址
        final homeserver = widget.homeserver;
        final url = Uri.parse('$homeserver/_matrix/client/v3/reset-password');
        debugPrint('reset-password url: $url');

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'phone': _phoneController.text,
            'username': _phoneController.text,
            'verification_code': _codeController.text,
            'password': _passwordController.text,
            'auth': {
              'type': '',
            },
          }),
        );

        final result = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('重置密码结果: $result');

        if (response.statusCode == 200) {
          _showSnackBar('重置密码成功！即将跳转到登录页');

          // 延迟一段时间后跳转到登录页
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pop(context);
          });
        } else {
          _showSnackBar(result['message'] ?? '重置密码失败，请重试');
        }
      } catch (e) {
        debugPrint('重置密码异常: $e');
        _showSnackBar('网络异常，请检查网络连接');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 验证手机号格式
  bool _isPhoneNumberValid(String phone) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  // 显示提示信息
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    // 释放控制器资源
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _imageCaptchaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重置密码'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 手机号输入框
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: '手机号',
                    hintText: '请输入11位手机号',
                    prefixIcon: const Icon(Icons.phone),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入手机号';
                    }
                    if (!_isPhoneNumberValid(value)) {
                      return '请输入有效的手机号';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 图片验证码
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _imageCaptchaController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: '图片验证码',
                          hintText: '请输入图中字符',
                          prefixIcon: const Icon(Icons.security),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入图片验证码';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 图片验证码显示区域
                    SizedBox(
                      width: 120,
                      height: 60,
                      child: _buildCaptchaImage(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 手机验证码输入框和获取按钮
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          labelText: '手机验证码',
                          hintText: '请输入6位验证码',
                          prefixIcon: const Icon(Icons.code),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入手机验证码';
                          }
                          if (value.length != 6) {
                            return '验证码长度为6位';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: (_isCountingDown || _isLoading)
                            ? null
                            : _startCountdown,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isCountingDown || _isLoading)
                              ? Colors.grey
                              : Theme.of(context).primaryColor,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                _isCountingDown
                                    ? '${_countdownSeconds}s后重发'
                                    : '获取验证码',
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 密码输入框
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: '设置密码',
                    hintText: '请设置6-20位密码',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请设置密码';
                    }
                    if (value.length < 6 || value.length > 20) {
                      return '密码长度为6-20位';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // 重置密码按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            '重置密码',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建图片验证码组件
  Widget _buildCaptchaImage() {
    if (_captchaImageData != null) {
      return GestureDetector(
        onTap: _refreshImageCaptcha,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Image.memory(
            _captchaImageData!,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: _refreshImageCaptcha,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              '点击加载',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    }
  }
}
