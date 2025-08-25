import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kapwa_companion_basic/screens/payment/mock_payment_screen.dart';
import 'package:kapwa_companion_basic/core/config.dart';
import 'package:logging/logging.dart';

class SubscriptionTermsConditionsScreen extends StatefulWidget {
  final double amount;
  final String planType;
  
  const SubscriptionTermsConditionsScreen({
    super.key,
    required this.amount,
    required this.planType,
  });

  @override
  State<SubscriptionTermsConditionsScreen> createState() => _SubscriptionTermsConditionsScreenState();
}

class _SubscriptionTermsConditionsScreenState extends State<SubscriptionTermsConditionsScreen> {
  static final Logger _logger = Logger('SubscriptionTermsConditionsScreen');

  void _continueToPayment() {
    _logger.info('User agreed to subscription terms, proceeding to payment');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MockPaymentScreen(
          amount: widget.amount,
          planType: widget.planType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('SubscriptionTermsConditionsScreen build - amount: ${widget.amount}, planType: ${widget.planType}');
    
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: const Text('Mga Tuntunin ng Subscription'),
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
                      'Mga Tuntunin at Kondisyon ng Subscription',
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
                    
                    // Subscription Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[800]?.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[800]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Buod ng Subscription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Plan:',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                widget.planType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Buwanang Presyo:',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '\$${widget.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSection(
                      'Mga Tuntunin sa Pagbabayad',
                      'Sa pag-subscribe, pinapahintulutan mo kaming singilan ang inyong paraan ng pagbabayad ng \$${widget.amount.toStringAsFixed(2)} buwanang. '
                          'Ang inyong subscription ay awtomatikong mag-renew bawat buwan sa parehong petsa maliban kung ikansela. '
                          'Kayo ay sisingilin kaagad pagkatapos ng kumpirmasyon.',
                    ),
                    _buildSection(
                      'Pagproseso ng Bayad',
                      'Ang inyong bayad ay ligtas na ipoproseso sa pamamagitan ng aming payment provider (Stripe). '
                          'Hindi namin iniimbak ang inyong mga detalye ng pagbabayad sa aming mga server. '
                          'Lahat ng transaksyon ay naka-encrypt at ligtas.',
                    ),
                    _buildSection(
                      'Patakaran sa Pagkansela',
                      'Maaari ninyong kanselahin ang inyong subscription anumang oras sa pamamagitan ng inyong Profile page. '
                          'Pagkatapos ng pagkansela, mapapanatili ninyo ang access sa premium features hanggang sa katapusan ng inyong kasalukuyang billing period. '
                          'Walang partial refunds na ibibigay para sa hindi nagamit na bahagi ng inyong subscription.',
                    ),
                    _buildSection(
                      'Patakaran sa Refund',
                      'Dahil sa kalikasan ng mga digital services, karaniwang hindi kami nag-aalok ng refunds kapag naproseso na ang bayad. '
                          'Dapat ninyong kanselahin ang inyong subscription upang maiwasan ang mga susunod na singil.',
                    ),
                    _buildSection(
                      'Pagkakaroon ng Serbisyo',
                      'Nagsusumikap kaming magbigay ng tuloy-tuloy na pagkakaroon ng serbisyo. Gayunpaman, hindi namin ginagarantiya '
                          'ang walang tigil na access at maaaring magsagawa ng maintenance na pansamantalang makakaapekto sa pagkakaroon ng serbisyo. '
                          'Walang refunds na ibibigay para sa pansamantalang pagkakatigil ng serbisyo.',
                    ),
                    _buildSection(
                      'Mga Pagbabago sa Presyo',
                      'Nakalaan namin ang karapatan na baguhin ang presyo ng subscription na may 30 araw na advance notice. '
                          'Ang mga kasalukuyang subscribers ay aabisuhan sa anumang pagbabago sa presyo at maaaring pumili na magkansela '
                          'bago magkabisa ang bagong presyo.',
                    ),
                    _buildSection(
                      'Pagwawakas ng Account',
                      'Nakalaan namin ang karapatan na wakasan ang mga account na lumalabag sa aming terms of service. '
                          'Sa kaso ng pagwawakas ng account dahil sa paglabag sa patakaran, walang refunds na ibibigay.',
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
                      onPressed: _continueToPayment,
                      child: Text(
                        'Sumasang-ayon ako at Magpatuloy sa Pagbabayad (\$${widget.amount.toStringAsFixed(2)})',
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