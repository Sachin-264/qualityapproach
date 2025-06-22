// lib/ReportDashboard/dashboardWidget/dashboard_icon_picker.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IconPickerDialog extends StatelessWidget {
  final IconData selectedIcon;

  const IconPickerDialog({Key? key, required this.selectedIcon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<IconData> commonIcons = [
      Icons.dashboard, Icons.bar_chart, Icons.show_chart, Icons.table_chart,
      Icons.analytics, Icons.data_usage, Icons.receipt_long, Icons.shopping_cart,
      Icons.person, Icons.business, Icons.monetization_on, Icons.attach_money,
      Icons.trending_up, Icons.notifications, Icons.settings, Icons.info,
      Icons.folder, Icons.pie_chart, Icons.bubble_chart, Icons.scatter_plot,
      Icons.calendar_today, Icons.access_time, Icons.location_on, Icons.email,
      Icons.phone, Icons.web, Icons.cloud, Icons.storage,
      Icons.account_balance, Icons.credit_card, Icons.group, Icons.lightbulb,
      Icons.star, Icons.favorite, Icons.check_circle, Icons.error,
      Icons.warning, Icons.help_outline, Icons.description, Icons.list_alt,
      Icons.grid_on, Icons.layers, Icons.category, Icons.label,
      Icons.vpn_key, Icons.lock, Icons.person_add, Icons.supervised_user_circle,
      Icons.security, Icons.cloud_upload, Icons.cloud_download, Icons.cloud_queue,
      Icons.sync, Icons.cached, Icons.refresh, Icons.build,
      Icons.extension, Icons.widgets, Icons.tune, Icons.filter_list,
      Icons.sort, Icons.search, Icons.menu, Icons.more_vert,
      Icons.add, Icons.remove, Icons.edit, Icons.delete,
      Icons.save, Icons.print, Icons.share, Icons.download,
      Icons.upload, Icons.history, Icons.bookmark, Icons.tag,
      Icons.attach_file, Icons.image, Icons.photo_library, Icons.video_library,
      Icons.music_note, Icons.palette, Icons.color_lens, Icons.format_paint,
      Icons.format_size, Icons.format_align_left, Icons.format_align_center, Icons.format_align_right,
      Icons.format_bold, Icons.format_italic, Icons.format_underline, Icons.text_fields,
      Icons.text_format, Icons.line_weight, Icons.opacity, Icons.texture,
    ];

    return AlertDialog(
      title: Text('Choose an Icon', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: SizedBox( // FIX 2: Explicitly constrain the GridView's height
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6, // Set a fixed height for the grid
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: commonIcons.length,
          itemBuilder: (ctx, index) {
            final icon = commonIcons[index];
            return InkWell(
              onTap: () => Navigator.of(context).pop(icon),
              child: Container(
                decoration: BoxDecoration(
                  color: selectedIcon == icon ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: selectedIcon == icon ? Theme.of(context).primaryColor : Colors.grey.shade300,
                    width: selectedIcon == icon ? 2.0 : 1.0,
                  ),
                ),
                child: Icon(icon, size: 36, color: selectedIcon == icon ? Theme.of(context).primaryColor : Colors.grey.shade700),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
        ),
      ],
    );
  }
}