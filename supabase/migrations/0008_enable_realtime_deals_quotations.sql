-- Enable realtime for deals and quotations tables
ALTER PUBLICATION supabase_realtime ADD TABLE deals, quotations;
