import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple language service — stores and exposes the app language (English / Urdu).
///
/// Extends [ChangeNotifier] so any widget that calls
/// `context.watch<LanguageService>()` (or wraps with [ListenableBuilder] /
/// [AnimatedBuilder]) rebuilds automatically when the language changes.
/// Screens no longer need to call setState manually after [setUrdu].
class LanguageService extends ChangeNotifier {
  static final LanguageService _i = LanguageService._();
  factory LanguageService() => _i;
  LanguageService._();

  bool _isUrdu = false;
  bool get isUrdu => _isUrdu;
  String get code => _isUrdu ? 'ur' : 'en';

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getBool('app_lang_urdu') ?? false;
    if (saved != _isUrdu) {
      _isUrdu = saved;
      // Notify after init only if the value differs from the default so
      // widgets built before init() completes don't rebuild needlessly.
      notifyListeners();
    }
  }

  Future<void> setUrdu(bool v) async {
    if (_isUrdu == v) return; // no-op if unchanged
    _isUrdu = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('app_lang_urdu', v);
    notifyListeners(); // rebuilds every listening widget automatically
  }

  String t(String en, String ur) => _isUrdu ? ur : en;
}

/// All user-visible strings in English and Urdu.
class S {
  static final _l = LanguageService();

  // ── Role Select ─────────────────────────────────────────────────────────
  static String get appTagline =>
      _l.t("Pakistan's Smartest Home Services", "پاکستان کی سب سے ذہین گھریلو خدمت");
  static String get whoAreYou => _l.t("Who are you?", "آپ کون ہیں؟");
  static String get selectRole =>
      _l.t("Select your role to continue", "جاری رکھنے کے لیے اپنا کردار منتخب کریں");
  static String get needService => _l.t("I need a service", "مجھے خدمت چاہیے");
  static String get needServiceSub =>
      _l.t("Find plumbers, electricians &\nmore near you",
          "اپنے قریب پلمبر، بجلی کار\nاور مزید تلاش کریں");
  static String get offerService => _l.t("I offer a service", "میں خدمت دیتا ہوں");
  static String get offerServiceSub =>
      _l.t("Register as a worker and\nget more customers",
          "کارکن کے طور پر رجسٹر ہوں\nاور زیادہ گاہک پائیں");

  // ── Login ────────────────────────────────────────────────────────────────
  static String get loginTitle => _l.t("Welcome Back!", "خوش آمدید!");
  static String get loginSub => _l.t("Sign in to your account", "اپنے اکاؤنٹ میں داخل ہوں");
  static String get phone => _l.t("Phone Number", "فون نمبر");
  static String get password => _l.t("Password", "پاس ورڈ");
  static String get signIn => _l.t("Sign In", "داخل ہوں");
  static String get noAccount =>
      _l.t("Don't have an account? Register", "اکاؤنٹ نہیں ہے؟ رجسٹر کریں");
  static String get forgotPass => _l.t("Forgot Password?", "پاس ورڈ بھول گئے؟");

  // ── Home ─────────────────────────────────────────────────────────────────
  static String get whatNeed => _l.t("What do you need?", "آپ کو کیا چاہیے؟");
  static String get searchHint => _l.t("Type in English or Urdu", "اردو یا انگریزی میں لکھیں");
  static String get browseWorkers => _l.t("Browse Workers", "کارکن دیکھیں");
  static String get seeAll => _l.t("See All", "سب دیکھیں");
  static String get voiceBook => _l.t("Book with Voice AI", "آواز سے بکنگ کریں");
  static String get voiceBookSub =>
      _l.t("Let our assistant find the perfect worker",
          "ہمارا معاون آپ کا بہترین کارکن تلاش کرے گا");

  // ── Agents ───────────────────────────────────────────────────────────────
  static String get agentIntent =>
      _l.t("Understanding your request", "آپ کی درخواست سمجھ رہے ہیں");
  static String get agentMatching =>
      _l.t("Finding workers near you", "آپ کے قریب کارکن تلاش کر رہے ہیں");
  static String get agentSurge =>
      _l.t("Checking demand in your area", "آپ کے علاقے میں مانگ جانچ رہے ہیں");
  static String get agentPricing =>
      _l.t("Calculating the best price", "بہترین قیمت تیار کر رہے ہیں");
  static String get agentScheduling =>
      _l.t("Checking worker availability", "کارکن کی دستیابی جانچ رہے ہیں");
  static String get agentBooking =>
      _l.t("Confirming your booking", "آپ کی بکنگ تصدیق ہو رہی ہے");
  static String get agentDispute =>
      _l.t("Reviewing your complaint", "آپ کی شکایت کا جائزہ لیا جا رہا ہے");
  static String get agentFeedback =>
      _l.t("Saving your feedback", "آپ کی رائے محفوظ ہو رہی ہے");

  // ── General ──────────────────────────────────────────────────────────────
  static String get cancel => _l.t("Cancel", "منسوخ کریں");
  static String get confirm => _l.t("Confirm", "تصدیق کریں");
  static String get back => _l.t("Back", "واپس");
  static String get next => _l.t("Next", "اگلا");
  static String get submit => _l.t("Submit", "جمع کریں");
  static String get loading => _l.t("Please wait...", "انتظار کریں...");
  static String get error => _l.t("Something went wrong.", "کچھ غلط ہو گیا۔");
  static String get success => _l.t("Success!", "کامیابی!");
}