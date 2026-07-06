import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_provider.dart';
import 'supplier_form_screen.dart';

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final suppliers = context.watch<SupplierProvider>().suppliers;

    return Scaffold(
      body: suppliers.isEmpty
          ? const Center(child: Text('No suppliers yet — add one below'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: suppliers.length,
              itemBuilder: (context, i) {
                final s = suppliers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                    title: Text(s.name),
                    subtitle: Text('${s.contactPerson} · ${s.phone}\n${s.email}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SupplierFormScreen(existing: s)));
                        } else if (v == 'delete') {
                          context.read<SupplierProvider>().deleteSupplier(s.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addSupplier',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SupplierFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
