from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='HabitClusterPrediction',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('cluster_id', models.IntegerField()),
                ('cluster_label', models.CharField(max_length=120)),
                ('insight_message', models.TextField()),
                ('recommendations', models.JSONField(default=list)),
                ('source', models.CharField(choices=[('on_demand', 'On Demand'), ('weekly', 'Weekly Scheduled')], default='on_demand', max_length=20)),
                ('input_payload', models.JSONField(default=dict)),
                ('processed_features', models.JSONField(default=list)),
                ('cluster_breakdown', models.JSONField(default=dict)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='habit_cluster_predictions', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'habit_cluster_predictions',
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='habitclusterprediction',
            index=models.Index(fields=['user', 'created_at'], name='habit_clust_user_id_ecc4ee_idx'),
        ),
        migrations.AddIndex(
            model_name='habitclusterprediction',
            index=models.Index(fields=['user', 'cluster_id'], name='habit_clust_user_id_24b53d_idx'),
        ),
    ]
