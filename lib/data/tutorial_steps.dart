import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/tutorial_overlay.dart';

/// Rich interactive tutorial steps for all 4 system sides:
/// - Branch Cook / Staff
/// - Driver
/// - Production Staff (Cook / Cutter)
/// - Owner Web
class TutorialSteps {
  // ───────────────────────────────────────────────────────────────────────────
  // 1. BRANCH COOK / STAFF APP (7 STEPS)
  // ───────────────────────────────────────────────────────────────────────────
  static final List<TutorialStep> staffSteps = [
    TutorialStep(
      icon: Icons.store_rounded,
      stepBadge: 'BRANCH COOK',
      title: 'Branch Status & Morning Setup',
      actionInstruction: 'Tingnan ang assigned branch at store status pagka-login.',
      description:
          'Dito makikita ang iyong itinalagang branch (hal. Brgy. Gatid) at kung bukas na ang tindahan. Kapag nag-tap ka ng RFID sa portable reader ng driver pagdating niya, awtomatikong magiging "OPEN" ang branch at maitala ang iyong Time-In.',
      interactivePreview: const _MockBranchCard(),
      tip: 'Siguraduhing naka-tap ang iyong RFID pagdating ng Driver upang maging bukas ang tindahan.',
    ),
    TutorialStep(
      icon: Icons.point_of_sale_rounded,
      stepBadge: 'QUICK POS',
      title: 'Pagtatala ng Benta (Order Punching)',
      actionInstruction: 'Pindutin ang "+1 REGULAR SISIG" kapag may umorder.',
      description:
          'Sa tuwing may bumibili, pindutin ang kaukulang button. Real-time na mababawasan ang karne, toyo, mayo, at styro sa system, at awtomatikong madadagdagan ang iyong sales at komisyon.',
      interactivePreview: const _MockCookPosButton(),
      tip: 'Pindutin agad ang button bawat order — huwag ipunin sa dulo ng shift.',
    ),
    TutorialStep(
      icon: Icons.inventory_2_rounded,
      stepBadge: 'INVENTORY METERS',
      title: 'Real-Time Inventory Monitoring',
      actionInstruction: 'Bantayan ang live stock meters sa ibaba ng POS.',
      description:
          'Kusang nag-uupdate ang mga metro ng karne at sangkap. Kapag mababa na sa 25% (pula), maaari kang mag-request ng restock sa Owner o maghanda ng contingency.',
      interactivePreview: const _MockInventoryMeter(),
      tip: 'Maging alerto kapag nagkulay dilaw o pula ang bar ng Regular o Medium meat.',
    ),
    TutorialStep(
      icon: Icons.report_problem_rounded,
      stepBadge: 'SPOILAGE / WASTAGE',
      title: 'Pag-report ng Tapon o Panis (Spoilage)',
      actionInstruction: 'Pindutin ang "Report Spoilage" kung may natapon.',
      description:
          'Kung may karne na nahulog sa sahig o nasunog, i-report agad ang bilang at dahilan. Awtomatikong mababawasan ang imbentaryo at makakaltas ang penalty sa EOD wage computation.',
      interactivePreview: const _MockSpoilageButton(),
      tip: 'I-report nang tapat ang anumang nasayang para laging tugma ang pisikal na bilang sa system.',
    ),
    TutorialStep(
      icon: Icons.payments_rounded,
      stepBadge: 'CLOSING EOD',
      title: 'End of Day Closing Sales & Remittance',
      actionInstruction: 'I-verify ang natirang stock at pindutin ang "Submit Final Sales".',
      description:
          'Sa pagsasara ng tindahan, kumpirmahin ang bilang ng natirang karne at styro. Awtomatikong kukuwentahin ng system ang Gross Revenue, ibabawas ang iyong Sweldo at Komisyon, at ipapakita ang eksaktong Cash Remittance na iaabot sa Driver.',
      interactivePreview: const _MockClosingSalesButton(),
      tip: 'Hindi na mababago ang sales report kapag naisumite na, kaya double check bago i-submit.',
    ),
    TutorialStep(
      icon: Icons.assignment_late_rounded,
      stepBadge: 'DAILY REPORT',
      title: 'Pang-araw-araw na Ulat (Incidents)',
      actionInstruction: 'I-toggle ang problema tulad ng butas na mayo o naubos na gas.',
      description:
          'Gamitin ang Daily Report tab para i-alerto agad ang Owner kung may naubos na LPG o nabutas na mayo. Makakatanggap ng agarang notification ang Owner sa kanyang dashboard.',
      interactivePreview: const _MockDailyReportCheckboxes(),
      tip: 'Maaari ring maglagay ng mensahe para sa anumang ibang kaganapan sa branch.',
    ),
    TutorialStep(
      icon: Icons.shopping_bag_rounded,
      stepBadge: 'BILAO ORDERS',
      title: 'Advance Bilao Orders',
      actionInstruction: 'Pindutin ang "Mark as Ready" kapag naluto na ang Bilao.',
      description:
          'Kung may nag-order nang advance na Sisig Bilao para sa branch mo, lulutuin ito at mamarkahan na handa na bago dumating ang customer o driver para mag-pickup.',
      interactivePreview: const _MockBilaoButton(),
      tip: 'I-check ang bilao pickup time upang laging mainit at sariwa ang bagnet pagdating ng kustomer.',
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // 2. DRIVER APP (5 STEPS)
  // ───────────────────────────────────────────────────────────────────────────
  static final List<TutorialStep> driverSteps = [
    TutorialStep(
      icon: Icons.route_rounded,
      stepBadge: 'DAILY ROUTE',
      title: 'Sunod-sunod na Rutang Babiyahein',
      actionInstruction: 'Tingnan ang assigned stops (Gatid → Labuin → Sta. Clara...).',
      description:
          'Ang mga stop ay may sequential locking: hindi maaaring laktawan ang Stop 2 hangga\'t hindi natatapos ang Stop 1. Tinitiyak nito na nasa tamang ruta at iskedyul ang delivery ng sariwang karne.',
      interactivePreview: const _MockRouteStopCard(),
      tip: 'Magsisimula ang ruta sa Main Warehouse kung saan ikinakarga ang mga pinalamig na karne.',
    ),
    TutorialStep(
      icon: Icons.add_alert_rounded,
      stepBadge: 'DISPATCH ALERT',
      title: 'Pag-alerto sa Branch Cook (On the Way)',
      actionInstruction: 'Pindutin ang "NOTIFY: ON THE WAY" bago umalis patungo sa branch.',
      description:
          'Isang tap lang, makakatanggap agad ang Branch Cook ng alert notification sa kanyang cellphone na paparating ka na, upang makapaghanda siya sa pagtanggap ng supplies.',
      interactivePreview: const _MockDriverNotifyButton(),
      tip: 'Pindutin ito mga 10-15 minuto bago makarating sa destinasyon.',
    ),
    TutorialStep(
      icon: Icons.nfc_rounded,
      stepBadge: 'RFID AUTOMATION',
      title: 'Auto-Complete gamit ang RFID Tap ng Cook',
      actionInstruction: 'Ipa-tap sa Branch Cook ang kanyang RFID Card sa portable reader.',
      description:
          'WALA NANG MANUAL NA DROPPED OFF BUTTON! Sa oras na itap ng Cook ang kanyang RFID sa reader na dala mo, kusa nang magtatala ang system ng Time-In ng cook, magiging OPEN ang branch, at kusa nang magiging "COMPLETED" ang iyong stop!',
      interactivePreview: const _MockRfidTapCard(),
      tip: 'Hawakan nang maayos ang portable ESP32 RFID device habang nagta-tap ang branch cook.',
    ),
    TutorialStep(
      icon: Icons.camera_alt_rounded,
      stepBadge: 'BILAO DELIVERY',
      title: 'Pagpapatunay ng Deliver na Bilao',
      actionInstruction: 'Kumuha ng litrato ng kustomer kasama ang Bilao.',
      description:
          'Para sa mga direct delivery ng bilao sa bahay ng kustomer, kuhanan ng litrato ang naihatid na bilao bilang digital proof of delivery bago i-mark ang order as Delivered.',
      interactivePreview: const _MockCameraDeliverButton(),
      tip: 'Siguraduhing malinaw ang kuha at kita ang bilao package.',
    ),
    TutorialStep(
      icon: Icons.task_alt_rounded,
      stepBadge: 'ROUTE COMPLETION',
      title: 'Pagtatapos ng Deployment at Retrieval',
      actionInstruction: 'I-remit ang nakolektang benta at unused items sa bodega.',
      description:
          'Kapag natapos ang 6 na stops sa hapon para sa retrieval, awtomatikong makukumpleto ang ruta at maia-upload ang kabuuang summary sa Owner Web dashboard.',
      interactivePreview: const _MockRouteSummaryCard(),
      tip: 'Ingatan ang cash collection envelopes mula sa bawat branch bago i-remit sa opisina.',
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // 3. PRODUCTION STAFF (5 STEPS)
  // ───────────────────────────────────────────────────────────────────────────
  static final List<TutorialStep> productionSteps = [
    TutorialStep(
      icon: Icons.soup_kitchen_rounded,
      stepBadge: 'PRODUCTION COOK',
      title: 'Batch Cooking Management',
      actionInstruction: 'Sundan ang target cooking weight para sa araw na ito.',
      description:
          'Makikita ng Production Cook kung ilang kilo ng karne ang lulutuin (hal. 40kg Pork Belly para sa Sisig). Pagkatapos maluto, itatala ang aktwal na cooked weight bago ipasa sa Meat Cutter.',
      interactivePreview: const _MockCookTaskCard(),
      tip: 'Maaari ring i-check ang lagay ng panahon upang malaman kung malakas ang demand sa araw.',
    ),
    TutorialStep(
      icon: Icons.content_cut_rounded,
      stepBadge: 'MEAT CUTTER',
      title: 'Paghahati ng Karne (Portioning Targets)',
      actionInstruction: 'Ipasok ang bilang ng 400g, 300g, at 250g packs.',
      description:
          'Kailangang tumugma nang eksakto ang bilang ng 400g (B1T1) at 300g (Medium) sa itinakdang target ng bodega. Hindi papayag ang system na mag-submit kung kulang o sobra ang bilang.',
      interactivePreview: const _MockPortioningInput(),
      tip: 'Tiyakin na calibrated ang digital weighing scale bago simulan ang pagbalot.',
    ),
    TutorialStep(
      icon: Icons.scale_rounded,
      stepBadge: 'SCRAP & NOTES',
      title: 'Natirang Scrap at Dahilan',
      actionInstruction: 'Itala ang natirang gramo ng scrap meat at paliwanag.',
      description:
          'Kung may natirang karne pagkatapos maabot ang targets, itala ang gramo (hal. 120g) at maglagay ng mandatory note tulad ng "Taba at litid trims" para sa buong transparency.',
      interactivePreview: const _MockScrapInput(),
      tip: 'Hindi maaaring mag-iwan ng scrap nang walang kaukulang paliwanag.',
    ),
    TutorialStep(
      icon: Icons.nfc_rounded,
      stepBadge: 'RFID WAREHOUSE',
      title: 'Attendance sa Bodega gamit ang RFID',
      actionInstruction: 'I-tap ang iyong RFID sa reader sa pintuan ng Main Warehouse.',
      description:
          'Bago magsimula ng shift, mag-tap sa nakadikit na RFID unit sa bodega. Ang unang tap sa umaga ang magsisilbing Time-In, at ang tap sa pag-uwi ang Time-Out.',
      interactivePreview: const _MockRfidTapCard(),
      tip: 'Bawal ipa-tap sa iba ang iyong card upang mapanatili ang integridad ng attendance.',
    ),
    TutorialStep(
      icon: Icons.inventory_rounded,
      stepBadge: 'BATCH DISPATCH',
      title: 'Serial Batch Linking para sa Driver',
      actionInstruction: 'I-link ang pinalamig na batch sa dispatch manifest.',
      description:
          'Bawat batch ay may serial code na konektado sa mga sangay. Sa ganitong paraan, alam ng may-ari kung aling batch ng karne ang napunta sa bawat sangay.',
      interactivePreview: const _MockBatchCard(),
      tip: 'Siguraduhing naka-pack sa tamang chiller container bago ikarga sa sasakyan ng driver.',
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // 4. OWNER WEB (5 STEPS)
  // ───────────────────────────────────────────────────────────────────────────
  static final List<TutorialStep> ownerSteps = [
    TutorialStep(
      icon: Icons.store_mall_directory_rounded,
      stepBadge: 'BRANCH OVERVIEW',
      title: 'Live Branch Status Matrix',
      actionInstruction: 'Subaybayan ang 6 na sangay nang real-time sa iisang screen.',
      description:
          'Makikita mo agad kung sinong Branch Cook ang pumasok na (RFID tap timestamp), kung bukas na ang tindahan, at kung on-the-way na ang driver patungo sa sangay.',
      interactivePreview: const _MockBranchStatusCard(),
      tip: 'Magre-refresh ito nang kusa nang hindi kailangang i-reload ang browser page.',
    ),
    TutorialStep(
      icon: Icons.local_shipping_rounded,
      stepBadge: 'RESTOCK CONTROL',
      title: 'Pag-restock ng Imbentaryo sa Sangay',
      actionInstruction: 'Piliin ang branch, ilagay ang bilang ng karne, at i-save.',
      description:
          'Mula sa Inventory section, piliin ang "Restock Branch". Ipasok ang bilang ng 250g, 300g, B1T1 packs, toyo, at mayo na ipadadala para sa deployment ng driver.',
      interactivePreview: const _MockRestockCard(),
      tip: 'May safety validation: bawal ang negative o mahigit sa 999 pcs bawat item.',
    ),
    TutorialStep(
      icon: Icons.how_to_reg_rounded,
      stepBadge: 'STAFF APPROVAL',
      title: 'Pag-apruba ng mga Bagong Aplikante',
      actionInstruction: 'Pindutin ang "APPROVE" pagkatapos suriin ang profile at lisensya.',
      description:
          'Bawat nagparehistrong staff o driver ay dadaan sa Account Approvals. Masusuri mo ang kanilang Philippine contact number, verified driver\'s license (via Gemini Vision AI), bago sila makapag-login.',
      interactivePreview: const _MockApplicantCard(),
      tip: 'Maaaring i-reject na may kasamang komento kung malabo ang na-upload na ID.',
    ),
    TutorialStep(
      icon: Icons.payments_rounded,
      stepBadge: 'SALES & PAYROLL',
      title: 'Kuwentada ng Benta at Komisyon',
      actionInstruction: 'Buksan ang Sales & Payroll para makita ang remittance ng bawat cook.',
      description:
          'Awtomatikong kukuwentahin ng system ang Daily Wage at Komisyon (hal. ₱5 bawat porsyon) at ang eksaktong Cash Remittance na dapat maiuwi ng driver pabalik sa opisina.',
      interactivePreview: const _MockSalesComputationCard(),
      tip: 'Maaaring i-export bilang CSV o PDF report para sa accounting audit.',
    ),
    TutorialStep(
      icon: Icons.campaign_rounded,
      stepBadge: 'ANNOUNCEMENTS',
      title: 'Paghahatid ng Anunsyo sa mga Device',
      actionInstruction: 'Piliin ang posisyon (Cook/Driver), i-type ang mensahe, at i-post.',
      description:
          'Makakapag-broadcast ka ng agarang balita tulad ng maagang pagsasara dahil sa bagyo. Agad itong lilitaw sa notification bell ng mga cellphone ng staff.',
      interactivePreview: const _MockAnnouncementCard(),
      tip: 'May limitasyon itong 500 characters para direkta at malinaw ang mensahe.',
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERACTIVE MOCK PREVIEW COMPONENTS (With actual live tap response)
// ─────────────────────────────────────────────────────────────────────────────

class _MockCookPosButton extends StatefulWidget {
  const _MockCookPosButton();

  @override
  State<_MockCookPosButton> createState() => _MockCookPosButtonState();
}

class _MockCookPosButtonState extends State<_MockCookPosButton> {
  int _orders = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _orders++);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B4513), Color(0xFFB45309)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B4513).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.add_circled_solid, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '+1 REGULAR SISIG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '₱130 · 250g karne',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(_orders),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _orders > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _orders > 0
                  ? '✓ Punched: $_orders order(s) | Karne stock: -$_orders portion(s)'
                  : 'I-tap ang button sa itaas para subukan!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _orders > 0 ? const Color(0xFF15803D) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MockBranchCard extends StatelessWidget {
  const _MockBranchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Brgy. Gatid, Sta. Cruz',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF24140B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OPEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Cook: Juan Dela Cruz (RFID In: 07:42 AM)', style: TextStyle(fontSize: 11, color: Color(0xFF7A6556))),
          const Text('Driver Status: En Route (ETA 8 mins)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
        ],
      ),
    );
  }
}

class _MockInventoryMeter extends StatelessWidget {
  const _MockInventoryMeter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Regular Meat (250g)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              Text('18/20 portions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.90,
              backgroundColor: Color(0xFFE5E7EB),
              color: Color(0xFF15803D),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Mayo Packs', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              Text('36/40 packs', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockSpoilageButton extends StatefulWidget {
  const _MockSpoilageButton();

  @override
  State<_MockSpoilageButton> createState() => _MockSpoilageButtonState();
}

class _MockSpoilageButtonState extends State<_MockSpoilageButton> {
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() => _reported = !_reported);
          },
          icon: const Icon(Icons.warning_amber_rounded, size: 16),
          label: Text(_reported ? 'Kanselahin ang Spoilage' : 'Report Spoilage (Tapon)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        if (_reported) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '✓ 1x Regular Sisig Naitala: -₱130 wage penalty sa EOD',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ],
    );
  }
}

class _MockClosingSalesButton extends StatefulWidget {
  const _MockClosingSalesButton();

  @override
  State<_MockClosingSalesButton> createState() => _MockClosingSalesButtonState();
}

class _MockClosingSalesButtonState extends State<_MockClosingSalesButton> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => _submitted = !_submitted),
          icon: Icon(_submitted ? Icons.check_circle_rounded : Icons.cloud_upload_rounded, size: 16),
          label: Text(_submitted ? '✓ Naisumite Na ang Sales' : 'Submit Final Closing Sales'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _submitted ? const Color(0xFF059669) : const Color(0xFF8B4513),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE8DED3)),
          ),
          child: const Text(
            'Gross: ₱4,550 · Sweldo: -₱450 · Remit: ₱4,100',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF24140B)),
          ),
        ),
      ],
    );
  }
}

class _MockDailyReportCheckboxes extends StatefulWidget {
  const _MockDailyReportCheckboxes();

  @override
  State<_MockDailyReportCheckboxes> createState() => _MockDailyReportCheckboxesState();
}

class _MockDailyReportCheckboxesState extends State<_MockDailyReportCheckboxes> {
  bool _mayoTorn = true;
  bool _gasEmpty = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _mayoTorn,
                activeColor: const Color(0xFF8B4513),
                onChanged: (v) => setState(() => _mayoTorn = v ?? false),
              ),
              const Expanded(
                child: Text('Nabutas ang Mayo Pack', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _gasEmpty,
                activeColor: const Color(0xFF8B4513),
                onChanged: (v) => setState(() => _gasEmpty = v ?? false),
              ),
              const Expanded(
                child: Text('Naubusan ng LPG Gas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockBilaoButton extends StatefulWidget {
  const _MockBilaoButton();

  @override
  State<_MockBilaoButton> createState() => _MockBilaoButtonState();
}

class _MockBilaoButtonState extends State<_MockBilaoButton> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bilao Order #BL-102 (Medium - ₱480)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: () => setState(() => _ready = !_ready),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ready ? const Color(0xFF059669) : const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                _ready ? '✓ Handa Na sa Pickup' : 'Mark as Ready for Pickup',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockRouteStopCard extends StatelessWidget {
  const _MockRouteStopCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
              SizedBox(width: 6),
              Expanded(child: Text('Stop 1: Brgy. Gatid (COMPLETED)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: const [
              Icon(Icons.local_shipping_rounded, color: Color(0xFFD97706), size: 16),
              SizedBox(width: 6),
              Expanded(child: Text('Stop 2: Brgy. Labuin (ACTIVE)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(height: 12),
          Row(
            children: const [
              Icon(Icons.lock_rounded, color: Colors.grey, size: 16),
              SizedBox(width: 6),
              Expanded(child: Text('Stop 3: Brgy. Sta. Clara (LOCKED 🔒)', style: TextStyle(fontSize: 11.5, color: Colors.grey))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockDriverNotifyButton extends StatefulWidget {
  const _MockDriverNotifyButton();

  @override
  State<_MockDriverNotifyButton> createState() => _MockDriverNotifyButtonState();
}

class _MockDriverNotifyButtonState extends State<_MockDriverNotifyButton> {
  bool _notified = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => _notified = !_notified),
          icon: Icon(_notified ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 16),
          label: Text(_notified ? '✓ Na-notify na ang Cook!' : 'NOTIFY: ON THE WAY'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _notified ? const Color(0xFF059669) : const Color(0xFFD97706),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _notified ? 'Nag-ring na ang alert sa phone ng Cook!' : 'Subukang i-tap ang button!',
          style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: _notified ? const Color(0xFF059669) : Colors.grey),
        ),
      ],
    );
  }
}

class _MockRfidTapCard extends StatefulWidget {
  const _MockRfidTapCard();

  @override
  State<_MockRfidTapCard> createState() => _MockRfidTapCardState();
}

class _MockRfidTapCardState extends State<_MockRfidTapCard> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _tapped = !_tapped),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _tapped ? const Color(0xFFDCFCE7) : const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _tapped ? const Color(0xFF059669) : const Color(0xFFE8DED3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc_rounded, color: _tapped ? const Color(0xFF059669) : const Color(0xFF8B4513), size: 24),
                const SizedBox(width: 8),
                Text(
                  _tapped ? 'BEEP! RFID TAPPED!' : 'I-tap dito (RFID Simulator)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _tapped ? const Color(0xFF059669) : const Color(0xFF8B4513),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _tapped
                  ? '✓ Time-In: 07:45 AM • Route Stop Auto-Completed!'
                  : 'UID: 4A 2B 9F 1C • Cook Card',
              style: TextStyle(
                fontSize: 11,
                fontWeight: _tapped ? FontWeight.bold : FontWeight.normal,
                color: _tapped ? const Color(0xFF15803D) : const Color(0xFF7A6556),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockCameraDeliverButton extends StatefulWidget {
  const _MockCameraDeliverButton();

  @override
  State<_MockCameraDeliverButton> createState() => _MockCameraDeliverButtonState();
}

class _MockCameraDeliverButtonState extends State<_MockCameraDeliverButton> {
  bool _captured = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _captured = !_captured),
            icon: Icon(_captured ? Icons.check_circle_rounded : Icons.camera_alt_rounded, size: 16),
            label: Text(_captured ? '✓ Photo Attached' : 'Capture Delivery Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B4513),
              side: const BorderSide(color: Color(0xFF8B4513)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          if (_captured) ...[
            const SizedBox(height: 6),
            const Text('Proof of delivery recorded with GPS timestamp.', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

class _MockRouteSummaryCard extends StatelessWidget {
  const _MockRouteSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: const [
          Text('6 / 6 Stops Completed (100%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(value: 1.0, color: Color(0xFF059669), minHeight: 6),
          ),
          SizedBox(height: 6),
          Text('Awtomatikong nai-record ang EOD summary.', style: TextStyle(fontSize: 10.5, color: Color(0xFF7A6556))),
        ],
      ),
    );
  }
}

class _MockCookTaskCard extends StatelessWidget {
  const _MockCookTaskCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Batch #1: Pork Belly Sisig', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Raw Target: 40.0 kg • Weather: Sunny (High Demand)', style: TextStyle(fontSize: 10.5, color: Color(0xFF7A6556))),
          SizedBox(height: 4),
          Text('Cooked Output: 36.2 kg (90.5% Yield)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
        ],
      ),
    );
  }
}

class _MockPortioningInput extends StatefulWidget {
  const _MockPortioningInput();

  @override
  State<_MockPortioningInput> createState() => _MockPortioningInputState();
}

class _MockPortioningInputState extends State<_MockPortioningInput> {
  int _b1t1 = 8;

  @override
  Widget build(BuildContext context) {
    final bool matched = _b1t1 == 10;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: matched ? const Color(0xFF059669) : const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('400g B1T1 Target (10 pcs):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: _b1t1 > 0 ? () => setState(() => _b1t1--) : null,
                  ),
                  Text('$_b1t1', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    onPressed: () => setState(() => _b1t1++),
                  ),
                ],
              ),
            ],
          ),
          Text(
            matched ? '✓ TARGET MATCHED: Eksaktong 10 pcs!' : 'Kulang ng ${10 - _b1t1} pcs (Pindutin ang +)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: matched ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockScrapInput extends StatelessWidget {
  const _MockScrapInput();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Meat Scrap Left: 120 g', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
          SizedBox(height: 4),
          Text('Reason Note: "Bone and fat trim excess"', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF7A6556))),
        ],
      ),
    );
  }
}

class _MockBatchCard extends StatelessWidget {
  const _MockBatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Serial Batch: BATCH-2026-1004-P1', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
          SizedBox(height: 4),
          Text('Dispatched to: Gatid, Labuin, Nanhaya', style: TextStyle(fontSize: 10.5, color: Color(0xFF7A6556))),
        ],
      ),
    );
  }
}

class _MockBranchStatusCard extends StatelessWidget {
  const _MockBranchStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Brgy. Gatid', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              Text('🟢 OPEN (Cook In: 7:42 AM)', style: TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Brgy. Dayap', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              Text('⚪ CLOSED (Waiting for Driver)', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockRestockCard extends StatelessWidget {
  const _MockRestockCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Destination: Brgy. Labuin, Pila', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Regular 250g: [ 20 ] pcs · Medium 300g: [ 10 ] pcs', style: TextStyle(fontSize: 10.5, color: Color(0xFF7A6556))),
          Text('B1T1 400g: [ 10 ] pcs · Mayo: [ 40 ] pcs', style: TextStyle(fontSize: 10.5, color: Color(0xFF7A6556))),
        ],
      ),
    );
  }
}

class _MockApplicantCard extends StatefulWidget {
  const _MockApplicantCard();

  @override
  State<_MockApplicantCard> createState() => _MockApplicantCardState();
}

class _MockApplicantCardState extends State<_MockApplicantCard> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pedro Santos (Driver Applicant)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          const Text('LTO License Verified via Gemini AI', style: TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_status != null)
            Text(
              '✓ Account Status: $_status',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _status == 'APPROVED' ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _status = 'APPROVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text('APPROVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _status = 'REJECTED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text('REJECT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MockSalesComputationCard extends StatelessWidget {
  const _MockSalesComputationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        children: const [
          Text('Sales Remittance Computation', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Gross: ₱5,200 · Sold: 40 portions', style: TextStyle(fontSize: 10.5, color: Color(0xFF7A6556))),
          Text('Cook Wage + Commission: -₱600', style: TextStyle(fontSize: 10.5, color: Color(0xFFDC2626))),
          Divider(height: 8),
          Text('Net Cash Remit to Driver: ₱4,600', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
        ],
      ),
    );
  }
}

class _MockAnnouncementCard extends StatelessWidget {
  const _MockAnnouncementCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Audience: All Branch Cooks', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
          SizedBox(height: 2),
          Text('"Bagyo Signal #1: Maagang magsasara sa ganap na 8:00 PM ang lahat ng sangay."', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF24140B))),
        ],
      ),
    );
  }
}
