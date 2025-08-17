import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/animation_utils.dart';

enum ButtonVariant { primary, secondary, outline, ghost, gradient }
enum ButtonSize { small, medium, large }

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool iconRight;
  final bool loading;
  final bool fullWidth;
  final List<Color>? gradientColors;
  final Color? customColor;
  
  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.loading = false,
    this.fullWidth = false,
    this.gradientColors,
    this.customColor,
  });
  
  const ModernButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.primary,
       gradientColors = null,
       customColor = null;
       
  const ModernButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.secondary,
       gradientColors = null,
       customColor = null;
       
  const ModernButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.outline,
       gradientColors = null,
       customColor = null;
       
  const ModernButton.gradient({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.loading = false,
    this.fullWidth = false,
    this.gradientColors = AppTheme.primaryGradient,
  }) : variant = ButtonVariant.gradient,
       customColor = null;

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.loading) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _resetAnimation();
  }

  void _onTapCancel() {
    _resetAnimation();
  }

  void _resetAnimation() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = widget.onPressed != null && !widget.loading;
    
    // Get button dimensions
    final dimensions = _getButtonDimensions();
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.fullWidth ? double.infinity : null,
            height: dimensions.height,
            child: _buildButton(context, isEnabled, dimensions),
          ),
        );
      },
    );
  }
  
  Widget _buildButton(BuildContext context, bool isEnabled, _ButtonDimensions dimensions) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (widget.variant == ButtonVariant.gradient) {
      return _buildGradientButton(context, isEnabled, dimensions);
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? widget.onPressed : null,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dimensions.horizontalPadding,
            vertical: dimensions.verticalPadding,
          ),
          decoration: _getButtonDecoration(context, isEnabled),
          child: _buildButtonContent(context, isEnabled, dimensions),
        ),
      ),
    );
  }
  
  Widget _buildGradientButton(BuildContext context, bool isEnabled, _ButtonDimensions dimensions) {
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled 
          ? LinearGradient(
              colors: widget.gradientColors ?? AppTheme.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
        color: isEnabled ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
        boxShadow: isEnabled ? [
          BoxShadow(
            color: (widget.gradientColors ?? AppTheme.primaryGradient).first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? widget.onPressed : null,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dimensions.horizontalPadding,
              vertical: dimensions.verticalPadding,
            ),
            child: _buildButtonContent(context, isEnabled, dimensions, forceWhiteText: true),
          ),
        ),
      ),
    );
  }
  
  Widget _buildButtonContent(BuildContext context, bool isEnabled, _ButtonDimensions dimensions, {bool forceWhiteText = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color textColor;
    if (forceWhiteText) {
      textColor = Colors.white;
    } else {
      switch (widget.variant) {
        case ButtonVariant.primary:
          textColor = isEnabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
          break;
        case ButtonVariant.secondary:
          textColor = isEnabled ? colorScheme.onSecondary : colorScheme.onSurfaceVariant;
          break;
        case ButtonVariant.outline:
        case ButtonVariant.ghost:
          textColor = isEnabled ? (widget.customColor ?? colorScheme.primary) : colorScheme.onSurfaceVariant;
          break;
        case ButtonVariant.gradient:
          textColor = Colors.white;
          break;
      }
    }
    
    final children = <Widget>[];
    
    if (widget.loading) {
      children.add(
        SizedBox(
          width: dimensions.iconSize,
          height: dimensions.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        ),
      );
    } else {
      if (widget.icon != null && !widget.iconRight) {
        children.add(Icon(widget.icon, size: dimensions.iconSize, color: textColor));
        children.add(SizedBox(width: dimensions.iconSpacing));
      }
      
      children.add(
        Text(
          widget.text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: dimensions.fontSize,
          ),
        ),
      );
      
      if (widget.icon != null && widget.iconRight) {
        children.add(SizedBox(width: dimensions.iconSpacing));
        children.add(Icon(widget.icon, size: dimensions.iconSize, color: textColor));
      }
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
  
  BoxDecoration _getButtonDecoration(BuildContext context, bool isEnabled) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimensions = _getButtonDimensions();
    
    switch (widget.variant) {
      case ButtonVariant.primary:
        return BoxDecoration(
          color: isEnabled ? (widget.customColor ?? colorScheme.primary) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: (widget.customColor ?? colorScheme.primary).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        );
        
      case ButtonVariant.secondary:
        return BoxDecoration(
          color: isEnabled ? colorScheme.secondary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
        );
        
      case ButtonVariant.outline:
        return BoxDecoration(
          color: _isPressed ? (widget.customColor ?? colorScheme.primary).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
          border: Border.all(
            color: isEnabled ? (widget.customColor ?? colorScheme.primary) : colorScheme.outline,
            width: 1.5,
          ),
        );
        
      case ButtonVariant.ghost:
        return BoxDecoration(
          color: _isPressed ? (widget.customColor ?? colorScheme.primary).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
        );
        
      case ButtonVariant.gradient:
        // Handled separately in _buildGradientButton
        return const BoxDecoration();
    }
  }
  
  _ButtonDimensions _getButtonDimensions() {
    switch (widget.size) {
      case ButtonSize.small:
        return _ButtonDimensions(
          height: 36,
          horizontalPadding: 16,
          verticalPadding: 8,
          fontSize: 14,
          iconSize: 16,
          iconSpacing: 6,
          borderRadius: 8,
        );
      case ButtonSize.medium:
        return _ButtonDimensions(
          height: 44,
          horizontalPadding: 20,
          verticalPadding: 12,
          fontSize: 16,
          iconSize: 18,
          iconSpacing: 8,
          borderRadius: 12,
        );
      case ButtonSize.large:
        return _ButtonDimensions(
          height: 52,
          horizontalPadding: 24,
          verticalPadding: 16,
          fontSize: 18,
          iconSize: 20,
          iconSpacing: 10,
          borderRadius: 14,
        );
    }
  }
}

class _ButtonDimensions {
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double iconSize;
  final double iconSpacing;
  final double borderRadius;
  
  _ButtonDimensions({
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
    required this.iconSize,
    required this.iconSpacing,
    required this.borderRadius,
  });
}