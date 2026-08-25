import { Document, Page, Text, View, StyleSheet, renderToBuffer } from '@react-pdf/renderer';

const styles = StyleSheet.create({
  page: {
    flexDirection: 'column',
    backgroundColor: '#ffffff',
    padding: 40,
    fontFamily: 'Helvetica',
  },
  header: {
    marginBottom: 30,
    borderBottomWidth: 2,
    borderBottomColor: '#1e293b',
    paddingBottom: 10,
  },
  title: {
    fontSize: 24,
    color: '#1e293b',
    fontWeight: 'bold',
  },
  subtitle: {
    fontSize: 12,
    color: '#64748b',
    marginTop: 4,
  },
  section: {
    margin: 10,
    padding: 10,
  },
  row: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    paddingVertical: 8,
  },
  label: {
    width: '40%',
    fontSize: 12,
    color: '#64748b',
  },
  value: {
    width: '60%',
    fontSize: 12,
    color: '#0f172a',
    fontWeight: 'bold',
  },
  footer: {
    position: 'absolute',
    bottom: 40,
    left: 40,
    right: 40,
    fontSize: 10,
    color: '#94a3b8',
    textAlign: 'center',
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
    paddingTop: 10,
  }
});

const QuotationDocument = ({ data }: { data: any }) => (
  <Document>
    <Page size="A4" style={styles.page}>
      <View style={styles.header}>
        <Text style={styles.title}>BrokerBridge Enterprise</Text>
        <Text style={styles.subtitle}>Official Quotation #{data.id?.split('-')[0].toUpperCase() || 'DRAFT'}</Text>
      </View>
      
      <View style={styles.section}>
        <View style={styles.row}>
          <Text style={styles.label}>Date of Issue:</Text>
          <Text style={styles.value}>{new Date().toLocaleDateString()}</Text>
        </View>
        <View style={styles.row}>
          <Text style={styles.label}>Valid Until:</Text>
          <Text style={styles.value}>{new Date(data.validUntil).toLocaleDateString()}</Text>
        </View>
        <View style={styles.row}>
          <Text style={styles.label}>Commodity:</Text>
          <Text style={styles.value}>{data.commodityName || 'N/A'}</Text>
        </View>
        <View style={styles.row}>
          <Text style={styles.label}>Quantity:</Text>
          <Text style={styles.value}>{data.quantity || 'N/A'}</Text>
        </View>
        <View style={styles.row}>
          <Text style={styles.label}>Offered Price:</Text>
          <Text style={styles.value}>INR {data.offeredPrice}</Text>
        </View>
      </View>

      <View style={{ marginTop: 40, padding: 10, backgroundColor: '#f8fafc' }}>
        <Text style={{ fontSize: 12, color: '#475569', lineHeight: 1.5 }}>
          This quotation is subject to final confirmation. Prices may fluctuate based on market conditions if not accepted by the validity date.
        </Text>
      </View>

      <Text style={styles.footer}>
        Generated securely via BrokerBridge Enterprise Network
      </Text>
    </Page>
  </Document>
);

export async function generateQuotationPdf(data: any): Promise<Buffer> {
  const pdfBuffer = await renderToBuffer(<QuotationDocument data={data} />);
  return pdfBuffer as Buffer;
}
