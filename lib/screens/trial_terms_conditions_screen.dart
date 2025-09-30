import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapwa_companion_basic/screens/payment/payment_screen.dart';
import 'package:kapwa_companion_basic/screens/auth/auth_wrapper.dart';
import 'package:kapwa_companion_basic/services/terms_acceptance_service.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class TrialTermsConditionsScreen extends StatefulWidget {
  final double? amount;
  final String? planType;
  final String? userId; // For initial terms acceptance
  final VoidCallback? onAccepted; // For initial terms acceptance
  
  const TrialTermsConditionsScreen({
    super.key,
    this.amount,
    this.planType,
    this.userId,
    this.onAccepted,
  });

  @override
  State<TrialTermsConditionsScreen> createState() => _TrialTermsConditionsScreenState();
}

class _TrialTermsConditionsScreenState extends State<TrialTermsConditionsScreen> {
  static final Logger _logger = Logger('TrialTermsConditionsScreen');
  bool _isAccepting = false;

  bool get _isInitialAcceptance => widget.userId != null && widget.onAccepted != null;
  bool get _isPaymentFlow => widget.amount != null && widget.planType != null;

  Future<void> _acceptTerms() async {
    if (!_isInitialAcceptance) return;

    setState(() {
      _isAccepting = true;
    });

    try {
      await TermsAcceptanceService.acceptTerms(widget.userId!);
      _logger.info('Terms accepted successfully for user: ${widget.userId}');
      widget.onAccepted!();
    } catch (e) {
      _logger.severe('Error accepting terms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting terms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  void _continueToPayment() {
    if (!_isPaymentFlow) return;
    
    _logger.info('Trial terms accepted, proceeding to IAP payment');
    print('🛒 DEBUG: Navigating from trial terms to IAP payment screen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('TrialTermsConditionsScreen build - userId: ${widget.userId}, amount: ${widget.amount}, planType: ${widget.planType}');
    _logger.info('_isInitialAcceptance: $_isInitialAcceptance, _isPaymentFlow: $_isPaymentFlow');
    
    // If neither flow is detected, this is an error - go back to login
    if (!_isInitialAcceptance && !_isPaymentFlow) {
      _logger.severe('TrialTermsConditionsScreen called without proper parameters - redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Mga Tuntunin ng Serbisyo at Patakaran sa Privacy'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mga Tuntunin ng Serbisyo at Patakaran sa Privacy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Huling na-update: Agosto 2, 2025',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      'Target na Audience',
                      'Ang application na ito ay partikular na ginawa para sa mga Overseas Filipino Workers (OFWs) upang makatulong sa kanilang mga pangangailangan. Kung hindi ka OFW, maaaring limitado lang ang makakamit mo sa mga features at serbisyo.',
                    ),
                    _buildSection(
                      'Panahon ng Trial',
                      'Ang mga bagong user ay makakakuha ng 7-araw na libreng trial period upang ma-explore ang mga features ng app. '
                          'Sa panahon ng inyong trial, may access kayo sa:\n'
                          '• 10,000 AI chat tokens bawat araw\n'
                          '• ${AppConfig.trialUserPodcastLimit} random na napiling podcast episodes bawat araw\n'
                          '• ${AppConfig.trialUserStoryLimit} random na napiling story audios bawat araw\n\n'
                          'Bawat araw, pipiliin ng app nang random ang ${AppConfig.trialUserPodcastLimit} bagong podcast episodes at ${AppConfig.trialUserStoryLimit} bagong story audios para sa inyong kasiyahan. '
                          'Ang inyong trial ay mag-expire automatically pagkatapos ng 7 araw, at maaari kayong mag-subscribe upang magpatuloy sa paggamit ng premium features.',
                    ),
                    _buildSection(
                      'AI Companion Disclaimer',
                      '**IMPORTANTE: Ito ay AI companion, hindi tunay na tao na tagapayo.**\n\n'
                          'Pakiintindi na:\n'
                          '• Ang AI companion ay maaaring magkamali at magbigay ng maling impormasyon\n'
                          '• HUWAG lubos na magtiwala sa AI advice para sa mahahalagang desisyon\n'
                          '• Ang app na ito ay para sa companionship at casual na usapan lamang\n'
                          '• HUWAG humingi ng payo tungkol sa financial, political, health, o marital na mga paksa\n'
                          '• HUWAG mag-attach emotionally sa AI - hindi ito tunay na tao\n'
                          '• Laging kumunsulta sa mga qualified professionals para sa seryosong mga bagay\n\n'
                          'Gamitin ang app na ito nang responsable at tandaan na ito ay tool lamang para sa friendly na conversation.',
                    ),
                    _buildSection(
                      'Mga Features ng Serbisyo',
                      'Ang Kapwa Companion ay nagbibigay ng AI-powered companionship, mga kuwento, at podcast content na partikular na ginawa para sa mga OFW. '
                          'Ang mga features ay maaaring ma-update o ma-modify upang mapabuti ang user experience. '
                          'Lahat ng content ay ginawa ng AI at dapat tratuhin bilang entertainment lamang, hindi professional advice.',
                    ),
                    _buildSection(
                      'Kasunduan sa Paggamit',
                      'Sa paggamit ng aming serbisyo, sumasang-ayon kayo na hindi:\n'
                          '• Ibahagi ang inyong account credentials\n'
                          '• Gamitin ang serbisyo para sa anumang illegal na layunin\n'
                          '• Ang paglabag sa mga tuntuning ito ay magreresulta sa pagtatapos ng inyong trial period.',
                    ),
                    _buildSection(
                      'Privacy at Data',
                      'Ang inyong privacy ay mahalaga sa amin. Hindi namin kinokolekta o sine-save ang inyong personal data sa aming database. Nag-store lang kami ng summary ng mga conversation para sa context, at kinokolekta lang namin ang violation data para sa security purposes.',
                    ),
                    _buildSection(
                      'Ugali ng User',
                      'Upang masiguro ang helpful at safe na community para sa lahat, may zero-tolerance policy kami para sa ilang mga ugali. '
                          'Sineseryoso namin ang mga violation na ito, at kung ma-trigger ninyo ang alinman sa mga sumusunod na flags ng tatlong beses, ang inyong account ay permanently banned:\n\n'
                          '• **Abuse/Hate:** Pakikipag-engage sa hateful o abusive na wika. Ang mga violation ay naka-flag bilang [FLAG:ABUSE]\n'
                          '• **Sexual Content:** Pag-uusap tungkol sa inappropriate sexual content. Ang mga violation ay naka-flag bilang [FLAG:SEXUAL]\n'
                          '• **Self-Harm:** Pag-uusap tungkol sa self-harm. Ang mga violation ay naka-flag bilang [FLAG:MENTAL_HEALTH]\n'
                          '• **Scams:** Pag-uusap tungkol sa fraudulent activities. Ang mga violation ay naka-flag bilang [FLAG:SCAM]',
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Patakaran sa Privacy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'Impormasyon na Kinokolekta Namin',
                      'Hindi namin kinokolekta at pinoproseso ang inyong personal data. Kinokolekta lang namin ang inyong email address kapag gumawa kayo ng account at violation data kung may na-trigger na flag.',
                    ),
                    _buildSection(
                      'Data Security',
                      'Nagpapatupad kami ng appropriate security measures upang protektahan ang inyong personal information. '
                          'Ang inyong data ay encrypted in transit at at rest. Ginagamit namin ang Firebase at iba pang secure '
                          'cloud services upang mag-store at mag-process ng inyong impormasyon.',
                    ),
                    _buildSection(
                      'Data Retention',
                      'Pinapanatili namin ang inyong email address kahit mag-expire na ang inyong trial o ma-ban kayo sa app upang maiwasan ang future violations. '
                          'Ang mga conversation summaries ay pinapanatili para sa context purposes pero walang personal information.',
                    ),
                    _buildSection(
                      'Community Support at Protection',
                      'Ang app na ito ay ginawa upang maging safe space para sa mga OFW. Committed kami sa pagprotekta sa aming community mula sa harmful content at behavior. Sa paggamit ng aming serbisyo, sumasang-ayon kayo na tumulong sa amin na mapanatili ang positive at supportive na environment para sa lahat ng users.',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[800]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isAccepting ? null : (_isInitialAcceptance ? _acceptTerms : _continueToPayment),
                      child: _isAccepting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isInitialAcceptance 
                                  ? 'Tinatanggap Ko ang mga Tuntunin at Kondisyon'
                                  : 'Sumasang-ayon Ako at Magpatuloy sa Payment',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
