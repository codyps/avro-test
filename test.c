#include <stdint.h>
#include <stdio.h>

#include <avro.h>


#define ARRAY_SIZE(x) (sizeof(x)/sizeof(x[0]))

static void print_value(avro_value_t *value, FILE *out)
{
	char *str;
	avro_value_to_json(value, 0, &str);
	fprintf(out, "%s\n", str);
	free(str);
}

int main(int argc, char **argv)
{
	if (argc != 2) {
		fprintf(stderr, "usage: %s <out-file>\n", argv[0]);
		return -1;
	}

	avro_writer_t w_stdout = avro_writer_file(stdout);
	avro_schema_t schema = avro_schema_array(avro_schema_int());
	avro_file_writer_t writer;
	int r = avro_file_writer_create(argv[1], schema, &writer);
	if (r < 0)
		return 1;

	avro_schema_to_json(schema, w_stdout);
	avro_value_iface_t *iface = avro_generic_class_from_schema(schema);

	avro_value_t value;
	r = avro_generic_value_new(iface, &value);
	if (r < 0)
		return 2;

	int foo[] = { 3, 4, 6, 7 };

	int i;
	avro_value_t elem;
	for (i = 0; i < ARRAY_SIZE(foo); i++) {
		r = avro_value_append(&value, &elem, NULL);
		avro_value_set_int(&elem, foo[i]);
	}


	print_value(&value, stdout);

	avro_file_writer_append_value(writer, &value);

	avro_file_writer_close(writer);
	avro_value_decref(&value);

	avro_schema_decref(schema);

	return 0;
}
