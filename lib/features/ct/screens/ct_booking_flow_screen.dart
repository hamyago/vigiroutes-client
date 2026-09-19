import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/ct_booking_controller.dart';
import '../../../core/constants/app_colors.dart';

class CtBookingFlowScreen extends StatefulWidget {
  const CtBookingFlowScreen({super.key});

  @override
  State<CtBookingFlowScreen> createState() => _CtBookingFlowScreenState();
}

class _CtBookingFlowScreenState extends State<CtBookingFlowScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CtBookingController>().loadVehicles();
    });
  }

  Widget _buildStep(CtBookingController ctrl) {
    switch (ctrl.step) {
      case 1:
        return _Step1VehicleSelection(ctrl: ctrl);
      case 2:
        return _Step2CenterAndSlot(ctrl: ctrl);
      case 3:
        return _Step3TransportMode(ctrl: ctrl);
      case 4:
        return _Step4Summary(ctrl: ctrl);
      case 5:
        return _Step5Payment(ctrl: ctrl);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CtBookingController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _StepIndicator(currentStep: ctrl.step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStep(ctrl),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Vehicle Selection
// ─────────────────────────────────────────────────────────────────────────────
class _Step1VehicleSelection extends StatelessWidget {
  final CtBookingController ctrl;
  const _Step1VehicleSelection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select Your Vehicle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (ctrl.isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (ctrl.error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ctrl.error!, style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: ctrl.loadVehicles,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ctrl.vehicles.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.divider),
              itemBuilder: (context, index) {
                final vehicle = ctrl.vehicles[index];
                final isSelected = ctrl.selectedVehicle?.id == vehicle.id;
                return ListTile(
                  tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  title: Text(
                    vehicle.registrationNumber,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${vehicle.brand} ${vehicle.model}'.trim(),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () => ctrl.selectVehicle(vehicle),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: ctrl.selectedVehicle != null ? () => ctrl.goToStep2() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Center & Slot
// ─────────────────────────────────────────────────────────────────────────────
class _Step2CenterAndSlot extends StatelessWidget {
  final CtBookingController ctrl;
  const _Step2CenterAndSlot({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Map
        SizedBox(
          height: 220,
          child: GoogleMap(
            onMapCreated: ctrl.onMapCreated,
            markers: ctrl.mapMarkers,
            initialCameraPosition: const CameraPosition(
              target: LatLng(14.6937, -17.4441),
              zoom: 12,
            ),
          ),
        ),
        // Date picker row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                ctrl.selectedDate != null
                    ? DateFormat('dd MMM yyyy').format(ctrl.selectedDate!)
                    : 'Pick a date',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) ctrl.selectDate(picked);
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text('Change'),
              ),
            ],
          ),
        ),
        Divider(color: AppColors.divider),
        // Centers list
        if (ctrl.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ctrl.availableCenters.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.divider),
              itemBuilder: (context, index) {
                final center = ctrl.availableCenters[index];
                final isSelected = ctrl.selectedCenter?.id == center.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        center.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        center.address ?? '',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ctrl.selectCenter(center);
                        if (ctrl.selectedDate != null) {
                          final d = ctrl.selectedDate!;
                          final dateStr =
                              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                          ctrl.loadSlots(dateStr);
                        }
                      },
                    ),
                    // Slots for this center
                    if (isSelected && ctrl.slots.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ctrl.slots.map((slot) {
                          final isSlotSelected =
                              ctrl.selectedSlot?.sessionId == slot.sessionId;
                          return ChoiceChip(
                            label: Text(slot.slotTime),
                            selected: isSlotSelected,
                            selectedColor: AppColors.primary,
                            onSelected: (_) => ctrl.selectSlot(slot),
                          );
                        }).toList(),
                      ),
                    if (isSelected && ctrl.slots.isEmpty && ctrl.selectedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No slots available for this date.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => ctrl.goBack(),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: ctrl.selectedCenter != null && ctrl.selectedSlot != null
                      ? () => ctrl.goToStep3()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Transport Mode
// ─────────────────────────────────────────────────────────────────────────────
class _Step3TransportMode extends StatelessWidget {
  final CtBookingController ctrl;
  const _Step3TransportMode({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'How will you bring your vehicle?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _TransportOption(
          value: 'self',
          label: 'Drive It Yourself',
          description: 'You drive your vehicle to the center.',
          icon: Icons.directions_car,
          selected: ctrl.transportMode,
          onSelect: ctrl.setTransportMode,
        ),
        _TransportOption(
          value: 'tow',
          label: 'Tow Service',
          description: 'We tow your vehicle to the center.',
          icon: Icons.local_shipping,
          selected: ctrl.transportMode,
          onSelect: ctrl.setTransportMode,
          fee: ctrl.towFee,
        ),
        _TransportOption(
          value: 'driver',
          label: 'Driver Service',
          description: 'A driver picks up and delivers your vehicle.',
          icon: Icons.person,
          selected: ctrl.transportMode,
          onSelect: ctrl.setTransportMode,
          fee: ctrl.driverFee,
        ),
        if (ctrl.transportMode == 'driver') ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Checkbox(
                  value: ctrl.keyHandoverAccepted,
                  activeColor: AppColors.primary,
                  onChanged: (v) => ctrl.setKeyHandoverAccepted(v ?? false),
                ),
                Expanded(
                  child: Text(
                    'I agree to hand over my keys to the driver.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => ctrl.goBack(),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: ctrl.canProceedStep3
                      ? () async {
                          final ok = await ctrl.initiateBooking();
                          if (ok) ctrl.goToStep4();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: ctrl.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Summary
// ─────────────────────────────────────────────────────────────────────────────
class _Step4Summary extends StatelessWidget {
  final CtBookingController ctrl;
  const _Step4Summary({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ctrl.activeBooking != null)
            _SlotReservationTimer(secondsLeft: ctrl.reservationSecondsLeft),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'Vehicle',
            child: _SummaryRow(
              label: ctrl.selectedVehicle?.registrationNumber ?? '',
              value: '${ctrl.selectedVehicle?.brand ?? ''} ${ctrl.selectedVehicle?.model ?? ''}'.trim(),
            ),
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Technical Center',
            child: Column(
              children: [
                _SummaryRow(label: 'Center', value: ctrl.selectedCenter?.name ?? ''),
                _SummaryRow(label: 'Address', value: ctrl.selectedCenter?.address ?? ''),
                _SummaryRow(
                  label: 'Date',
                  value: DateFormat('dd MMM yyyy').format(ctrl.selectedDate!),
                ),
                _SummaryRow(
                  label: 'Slot',
                  value: ctrl.selectedSlot?.slotTime ?? ctrl.selectedSlot?.sessionId ?? '',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Transport',
            child: _SummaryRow(
              label: 'Mode',
              value: ctrl.transportMode == 'self'
                  ? 'Drive Yourself'
                  : ctrl.transportMode == 'tow'
                      ? 'Tow Service'
                      : 'Driver Service',
            ),
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Fees',
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Inspection fee',
                  value: '${fmt.format(ctrl.bookingFee)} FCFA',
                ),
                if (ctrl.transportFee > 0)
                  _SummaryRow(
                    label: 'Transport fee',
                    value: '${fmt.format(ctrl.transportFee)} FCFA',
                  ),
                Divider(color: AppColors.divider),
                _SummaryRow(
                  label: 'Total',
                  value: '${fmt.format(ctrl.totalAmount)} FCFA',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Payment method selection
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _PaymentMethod(
            value: 'wave',
            label: 'Wave',
            icon: Icons.waves,
            selected: ctrl.paymentMethod,
            onSelect: ctrl.setPaymentMethod,
          ),
          _PaymentMethod(
            value: 'orange_money',
            label: 'Orange Money',
            icon: Icons.smartphone,
            selected: ctrl.paymentMethod,
            onSelect: ctrl.setPaymentMethod,
          ),
          _PaymentMethod(
            value: 'card',
            label: 'Card',
            icon: Icons.credit_card,
            selected: ctrl.paymentMethod,
            onSelect: ctrl.setPaymentMethod,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => ctrl.goBack(),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: ctrl.paymentMethod != null
                      ? () async {
                          final ok = await ctrl.pay();
                          if (ok) ctrl.setStep(5);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: ctrl.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Pay Now',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Payment
// ─────────────────────────────────────────────────────────────────────────────
class _Step5Payment extends StatelessWidget {
  final CtBookingController ctrl;
  const _Step5Payment({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ctrl.qrCodeUrl != null) ...[
              Text(
                'Scan QR Code to Pay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Image.network(ctrl.qrCodeUrl!, height: 200, width: 200),
            ] else if (ctrl.paymentUrl != null) ...[
              Text(
                'Complete Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Open paymentUrl in browser
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Payment Page'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Processing payment...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            _SlotReservationTimer(secondsLeft: ctrl.reservationSecondsLeft),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets — kept as-is (no GetX usage)
// ─────────────────────────────────────────────────────────────────────────────


class _SlotReservationTimer extends StatelessWidget {
  final int secondsLeft;
  const _SlotReservationTimer({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;
    final display = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isUrgent = secondsLeft < 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: isUrgent ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            'Slot reserved for: $display',
            style: TextStyle(
              color: isUrgent ? Colors.red.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportOption extends StatelessWidget {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final String selected;
  final void Function(String) onSelect;
  final double? fee;

  const _TransportOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onSelect,
    this.fee,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final fmt = NumberFormat('#,##0', 'fr');

    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (fee != null)
              Text(
                '+${fmt.format(fee)} F',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String? selected;
  final void Function(String) onSelect;

  const _PaymentMethod({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;

    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SummaryCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const totalSteps = 5;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(totalSteps, (index) {
            final stepNum = index + 1;
            final isActive = stepNum == currentStep;
            final isDone = stepNum < currentStep;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDone || isActive ? AppColors.primary : AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (index < totalSteps - 1) const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
